import google.generativeai as genai
import pandas as pd
import os


GEMINI_API_KEY = "AIzaSyA3ScUBOwzI9-SGmMblGGyb1kKA0mphm5A"
genai.configure(api_key=GEMINI_API_KEY)

# Load Verification Plan
xlsx_file = "/UVMTestGen/Vps/MiniUart_verifcationplan.xlsx"
df = pd.read_excel(xlsx_file, sheet_name="Verification Plan")

base_dir = "uvm_tests"
os.makedirs(base_dir, exist_ok=True)

model = genai.GenerativeModel("gemini-2.0-flash")

# Loop: each feature in VP
for _, row in df.iterrows():
    feature_name = row["Feature"]
    inputs = row["Testcase Inputs"]
    steps = row["Testcase Steps"]
    outputs = row["Testcase Outputs"]

    # Create folder for each feature
    feature_dir = os.path.join(base_dir, feature_name.replace(' ', '_').lower())
    os.makedirs(feature_dir, exist_ok=True)

    # Prompt
    prompt = f"""
You are a UVM SystemVerilog expert.  
Generate ONLY a UVM testcase in SystemVerilog for the following feature:
Feature: {feature_name}
Inputs: {inputs}
Steps: {steps}
Expected Outputs: {outputs}

The testcase must include:
- A UVM sequence sending transactions
- A UVM test class that starts the sequence
- Scoreboard checks for expected output

Do NOT add explanations or comments outside the code.
Output valid SystemVerilog code only.
"""

    response = model.generate_content(prompt)

    # Extract code text safely
    testcase_code = response.candidates[0].content.parts[0].text if response.candidates else ""

    # Save testcase file inside feature folder
    filename = os.path.join(feature_dir, f"{feature_name.replace(' ', '_').lower()}_test.sv")
    with open(filename, "w") as f:
        f.write(testcase_code)

    print(f"Generated: {filename}")
