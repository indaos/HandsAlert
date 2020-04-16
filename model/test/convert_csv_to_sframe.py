import turicreate as tc
from glob import glob

data_dir = './'

acc_files = glob(data_dir + 'mo*_*.csv')

data = tc.SFrame()
files = zip(sorted(acc_files))
for accfile in files:
    sf = tc.SFrame.read_csv(accfile[0], delimiter=',', header=False, verbose=True)
    sf = sf.rename({'X1': 'ax', 'X2': 'ay', 'X3': 'az','X4': 'gx', 'X5': 'gy', 'X6': 'gz','X7': 'eid', 'X8': 'act'})
    data = data.append(sf)
   
data.print_rows(num_rows=10000, num_columns=8) 

data.save('ham.sframe')
