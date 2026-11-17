# -*- coding: utf-8 -*-
"""
Train the RNN surrogate (emulator) of the change in surface speed.

RNN here is a residual neural network (class sr_RESNET). The network maps the ensemble parameters (predictors) to
the coefficients of the SVD basis of the change in speed (targets). Its hyperparameters are optimised with Bayesian
optimisation (keras-tuner); the best model is then retrained (i) on the training and validation data together and
(ii) on the training data only, and both are saved. The loss is the Huber loss of the fields reconstructed with the
truncated SVD basis B (matrix_loss).

Created on 01/08/2023 12:07
@author: shrro
Modified by jdr on 3/12/2024: remove preprocessing normalization of training data
Adapted from the training script of Rosier et al. (2025), The Cryosphere 19, 2527-2551,
https://tc.copernicus.org/articles/19/2527/2025/

USAGE (from the folder that contains <folder>/RNN/mat_files, e.g. ./Emulators)
    python RNN_network_optimisation_JDR_v5.py <folder> <fname>
    <folder> : domain folder, e.g. AMUND
    <fname>  : name of the data files without "data_" / "SVD_" and ".mat" (written by
               prep_EmulatorTrainingData_deltaU.m, option write_outputs_for_TF), e.g.
               AMUND_Calv_dh_2000-2009_Weertman-Umbi_cycle2-2_floatingice0_includemeasurements0_Basis_Wc2-Uc2-Comp25-Var50

INPUTS
    ./<folder>/RNN/mat_files/data_<fname>.mat : X_train, X_val, X_test, T_train, T_val, T_test
    ./<folder>/RNN/mat_files/SVD_<fname>.mat  : B_trunc (truncated SVD basis), T_pct (variance per retained component)

OUTPUTS (the folder ./<folder>/RNN/TF_files is created by the first model.save)
    v5_tuned_model_full_<fname> : model retrained on training + validation data (TensorFlow SavedModel)
    v5_tuned_model_<fname>      : model retrained on the training data only (SavedModel)
    v5_diary_<fname>.txt        : hyperparameter search space, best hyperparameters, losses
    Temporary tuner files: /tmp/v2/rnn_<fname>

REQUIREMENTS
    Python virtual environment named "tf213_env" with TensorFlow 2.13 (see the check below): the saved models are
    imported in MATLAB, which cannot import models saved with Keras 3. Packages: tensorflow 2.13, keras 2.13,
    keras-tuner, numpy, scipy. The script runs on the CPU only.
"""

import sys
import os

# ---- check the Python environment
# Expected venv name or path
EXPECTED_VENV_NAME = "tf213_env"  # or full path to your environment

# Detect current venv
current_venv = os.environ.get("VIRTUAL_ENV")  # works if venv is activated
current_python = sys.executable

if current_venv is None or EXPECTED_VENV_NAME not in current_venv:
    print(f"ERROR: Script must be run in the '{EXPECTED_VENV_NAME}' environment, which contains tensorflow 2.13.")
    print(f"The reason is that Matlab cannot import models from keras3, which is installed in the default environment.") 
    print(f"Current environment: {current_venv}")
    print(f"Python executable: {current_python}")
    print(f"To activate the environment, execute 'source tf213_env/bin/activate'")
    sys.exit(1)  # abort script

print(f"Running in correct environment: {current_venv}")

# ---- imports
# mlp for multi-output regression
from keras.layers import Dense
from keras.layers import BatchNormalization
from keras.layers import Dropout
from keras.layers import Add
from keras.layers import Activation
import numpy as np
import scipy.io
from tensorflow import keras
import tensorflow as tf
import keras_tuner as kt

# ---- model definition
def residual_block(x, block_depth=2, hidden_size=30, dropout_rate=0.0):
    # store the input tensor to be added later as the identity
    identity = x

    for _ in range(block_depth):
        x = BatchNormalization()(x) 
        x = Dense(hidden_size, kernel_initializer='he_uniform')(x)
        x = Activation('swish')(x)
        if dropout_rate > 0: 
            x = Dropout(dropout_rate)(x)

    x = Add()([identity, x])

    return x

class sr_RESNET(kt.HyperModel):

    def __init__(self, output_size, input_size, B, n):
        self.output_size = output_size
        self.input_size = input_size
        self.B = B
        self.n = n

    def build(self, hp):
    
        inputs = keras.Input(shape=(self.input_size,))

        x1 = inputs

        # increase capacity of hidden layer 
        hs = hp.Int('hidden_size', 64, 256, step=16, default=40)
             
        do = hp.Float('dropout_rate', 0.0, 0.2, step=0.1)

        x1 = Dense(hs, kernel_initializer='he_uniform', activation='swish')(x1)
        x1 = BatchNormalization()(x1)
        x1 = Dropout(do)(x1)

        nb = hp.Int('n_blocks', 1, 2, default=2)
        bd = hp.Int('block_depth', 2, 8, default=2)

        for _ in range(nb):
            x1 = residual_block(x1, block_depth=bd, hidden_size=hs, dropout_rate=do)

        outputs = Dense(self.output_size, dtype='float32')(x1)

        lr = hp.Float('learning_rate', 1e-4, 5e-2, sampling='log')

        model = keras.Model(inputs=inputs, outputs=outputs, name="resnet_v5")

        model.compile(
            optimizer=keras.optimizers.Adam(
                learning_rate=lr),
            loss=matrix_loss(B=self.B, n=self.n))

        return model

# Huber loss of the fields reconstructed from the first n SVD coefficients with the basis B
# TODO: prep_EmulatorTrainingData_deltaU.m normalises the targets (z-score per component) before writing T_train, but
# the loss multiplies by B without undoing that scaling: check that this weighting is intended.
def matrix_loss(B,n):
    huber = tf.keras.losses.Huber()
    def loss(y_true, y_pred):
        py = tf.linalg.matmul(y_true[:, 0:n], B)
        ua = tf.linalg.matmul(y_pred[:, 0:n], B)
        return huber(ua,py)
    return loss

# ---- settings and inputs
# restrict tensorflow to CPU
tf.config.set_visible_devices([], 'GPU')

# deal with inputs
if len(sys.argv) != 3:
    print("Usage: python RNN_network_optimisation_JDR_v5.py <folder> <fname>")
    sys.exit(1)
folder = sys.argv[1] # example format: AMUND
folder = str(folder)
fname = sys.argv[2] # example format: Calv_dh_2014-2018_Weertman_cycle2_N0k995
fname = str(fname)

# load dataset
mat = scipy.io.loadmat('./'+folder+'/RNN/mat_files/data_'+fname+'.mat')
mat2 = scipy.io.loadmat('./'+folder+'/RNN/mat_files/SVD_'+fname+'.mat')

X_train = mat['X_train']
Y_train = mat['T_train']

X_val = mat['X_val']
Y_val = mat['T_val']

X_test = mat['X_test']
Y_test = mat['T_test']

num_outputs = len(Y_train[0])
num_inputs = len(X_train[0])

B = mat2['B_trunc']
T_pct = mat2['T_pct']
n = np.shape(T_pct)[0]

B2 = tf.convert_to_tensor(B, dtype=tf.float32)

# ---- datasets
batch_size=256

train_ds = tf.data.Dataset.from_tensor_slices((X_train, Y_train))
train_ds = train_ds.shuffle(1024).batch(batch_size).cache().prefetch(tf.data.AUTOTUNE)

val_ds = tf.data.Dataset.from_tensor_slices((X_val, Y_val))
val_ds = val_ds.batch(batch_size).prefetch(tf.data.AUTOTUNE)

test_ds = tf.data.Dataset.from_tensor_slices((X_test, Y_test))
test_ds = test_ds.batch(batch_size).prefetch(tf.data.AUTOTUNE)

# ---- hyperparameter search (Bayesian optimisation)
# TODO: no random seeds are set (tensorflow, numpy), so the search and the training are not reproducible
tuner = kt.BayesianOptimization(
    sr_RESNET(num_outputs, num_inputs, B2, n),
    objective='val_loss',
    max_trials=120,
    max_consecutive_failed_trials=2,
    directory="/tmp/v2/rnn_"+fname,
    overwrite=True
)

tuner.search(
    train_ds,
    validation_data=val_ds,
    epochs=200,
    shuffle=True,
    verbose=1,
    callbacks=[
        tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=20, restore_best_weights=True)
    ]
)

# ---- retrain the best model and save it
best_model = tuner.get_best_models(1)[0]
best_hp = tuner.get_best_hyperparameters(1)[0]

# Rebuild model with best hyperparameters
model_full = tuner.hypermodel.build(best_hp)
# Retrain with more epochs and full dataset (training and validation data)
# Prepare combined training and validation data
X_combined = np.concatenate((X_train, X_val), axis=0)
Y_combined = np.concatenate((Y_train, Y_val), axis=0)
# Create a dataset from the combined data
combined_ds = tf.data.Dataset.from_tensor_slices((X_combined, Y_combined))
combined_ds = combined_ds.shuffle(1024).batch(batch_size).cache().prefetch(tf.data.AUTOTUNE)
# retrain model
model_full.fit(combined_ds, epochs=2000, verbose=1)
# save model
model_full.save("./"+folder+"/RNN/TF_files/v5_tuned_model_full_"+fname,save_format="tf")

# Rebuild model with best hyperparameters
model = tuner.hypermodel.build(best_hp)
# retrain model
model.fit(train_ds, epochs=2000, verbose=1)
# save model
model.save("./"+folder+"/RNN/TF_files/v5_tuned_model_"+fname,save_format="tf")

# ---- write a summary of the search and the losses
# TODO: 'model' (trained on the training data only) is evaluated on the combined data and labelled "training loss";
# model_full (trained on training + validation data) is not evaluated on the test data here.
diaryfname = "./" + folder + "/RNN/TF_files/v5_diary_" + fname + ".txt"
with open(diaryfname, "w") as f:

    # =====================================
    # 1) HYPERPARAMETER SEARCH SPACE
    # =====================================
    f.write("=== Hyperparameter Search Space ===\n")
    for hp in best_hp.space:
        f.write(f"\nName: {hp.name}\n")
        f.write(f"Type: {hp.__class__.__name__}\n")

        # Choice parameters
        if hasattr(hp, "values") and hp.values is not None:
            f.write(f"Possible values: {hp.values}\n")

        # Numerical ranges
        if hasattr(hp, "min_value"):
            f.write(f"Range: {hp.min_value} to {hp.max_value}\n")

        if hasattr(hp, "step") and hp.step is not None:
            f.write(f"Step size: {hp.step}\n")

        if hasattr(hp, "default"):
            f.write(f"Default: {hp.default}\n")
            
    # =============================
    # 2) BEST HYPERPARAMETER VALUES
    # =============================
    f.write("\n=== Best Hyperparameter Values ===\n")
    for key, value in best_hp.values.items():
        f.write(f"{key}: {value}\n")

    # ============================================================
    # 3) PERFORMANCE FOR BEST HYPERPARAMETERS (BEFORE RETRAINING)
    # ============================================================
    f.write("\n=== Performance with Best Hyperparameters (Before Retraining) ===\n")

    loss_train = best_model.evaluate(train_ds, return_dict=False)
    loss_val = best_model.evaluate(val_ds, return_dict=False)
    loss_test = best_model.evaluate(X_test, Y_test, batch_size=batch_size, return_dict=False)

    f.write(f"Training loss: {loss_train}\n")
    f.write(f"Validation loss: {loss_val}\n")
    f.write(f"Test loss: {loss_test}\n")

    # =======================================
    # 4) PERFORMANCE AFTER FULL RETRAINING
    # =======================================
    f.write("\n=== Performance After Full Retraining ===\n")

    final_loss = model.evaluate(combined_ds, return_dict=False)
    test_loss = model.evaluate(X_test, Y_test, batch_size=batch_size, return_dict=False)
    
    f.write(f"Final training loss (on combined dataset): {final_loss}\n")
    f.write(f"Test loss (after retraining): {test_loss}\n")
