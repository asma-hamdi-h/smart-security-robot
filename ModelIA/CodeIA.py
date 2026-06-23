import pandas as pd
from sklearn.tree import DecisionTreeClassifier, export_text

data = pd.read_excel(r"D:\Downloads\my project\Model IA\dataset_navigation_robot.xlsx")

X = data[["front_value", "left_value", "right_value"]]
y = data["decision"]

model = DecisionTreeClassifier()
model.fit(X, y)

rules = export_text(model, feature_names=["front", "left", "right"])

print(rules)
