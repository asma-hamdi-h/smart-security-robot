import pandas as pd
from sklearn.tree import DecisionTreeClassifier, export_text

# --------------------------
# 1. Lire Excel
# --------------------------
data = pd.read_excel(r"D:\proje_pfeFinal\ModelIA\dataset_robot_100.xlsx")

# entrées
X = data[["gaz", "mouvement", "son", "lumiere", "flamme"]]

# sorties
y_risk = data["risque"]
y_action = data["action"]

# --------------------------
# 2. Modèle risque
# --------------------------
model_risk = DecisionTreeClassifier(max_depth=4)
model_risk.fit(X, y_risk)

# --------------------------
# 3. Modèle action
# --------------------------
model_action = DecisionTreeClassifier(max_depth=4)
model_action.fit(X, y_action)

# --------------------------
# 4. Affichage arbre
# --------------------------
print("Arbre RISQUE:\n")
print(export_text(model_risk, feature_names=list(X.columns)))

print("\n Arbre ACTION:\n")
print(export_text(model_action, feature_names=list(X.columns)))

# --------------------------
# 5. Test
# --------------------------
test = [[80, 1, 0, 20, 0]]

risk = model_risk.predict(test)
action = model_action.predict(test)

print("\nRésultat IA :")
print("Risque :", risk)
print("Action :", action)