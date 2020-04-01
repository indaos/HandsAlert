### This Apple Watch app detects when you start washing your hands and warns you if you stop too soon.

Detection of hand washing in the background and notification if the process is too short. CoreML and the trained NN model 
are used to detect this process. The app can also collect data from the accelerometer and gyroscope for this training. 
Data is transferred to the iphone, where it is stored as a CSV file. Then you can move it to your computer and use Turi Create (https://github.com/apple/turicreate) to convert it to a CoreML model.

The app runs in the background and does not need to be started before washing your hands.
But this also creates a problem, because WatchOS only allows you to use one workout session at a time.It is not possible to start two workouts at the same time, so you need to restart the app after a normal workout.

There is also a problem with battery consumption. 
Obviously, an app that constantly reads the accelerometer and uses the prediction process once per second
(however, this process should not be heavy) consumes significant battery life.
