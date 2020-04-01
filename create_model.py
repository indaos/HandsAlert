import turicreate as tc

data = tc.SFrame('ham.sframe')

train, test = tc.activity_classifier.util.random_split_by_session(data,
                                                                  session_id='eid',
                                                                  fraction=0.8)

train.print_rows(num_rows=10000, num_columns=8) 

model = tc.activity_classifier.create(train, session_id='eid', target='act',prediction_window=50)

metrics = model.evaluate(test)
print(metrics['accuracy'])

model.save('ham.model')

model.export_coreml('HandsAlertActivityClassifier.mlmodel')
