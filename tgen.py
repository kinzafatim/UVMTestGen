import google.generativeai as genai
import pandas as pd
import os

# --- Gemini API Configuration ---
GEMINI_API_KEY = "AIzaSyA3ScUBOwzI9-SGmMblGGyb1kKA0mphm5A"
genai.configure(api_key=GEMINI_API_KEY)

# --- Load Verification Plan ---
xlsx_file = "Vps/MiniUart_verifcationplan.xlsx"
df = pd.read_excel(xlsx_file, sheet_name="Verification Plan")

# --- Paths ---
templates_dir = "Templates"
base_dir = "uvm_tests"
os.makedirs(base_dir, exist_ok=True)

# --- Load Template Files as Reference ---
def load_template(filename):
    path = os.path.join(templates_dir, filename)
    if os.path.exists(path):
        with open(path, "r") as f:
            return f.read()
    return ""

base_test_template = load_template("template_test.sv")
base_seq_template = load_template("template_sequence.sv")
seq_item_template = load_template("template_seq_item.sv")

# Combine all templates for LLM reference
template_reference = f"""
// ---------- Reference Templates ----------
{base_test_template}

{base_seq_template}

{seq_item_template}
// ---------- End Templates ----------
"""

# --- LLM Model ---
model = genai.GenerativeModel("gemini-2.0-flash")

# --- Generate UVM Testcases for Each Feature ---
for _, row in df.iterrows():
    feature_name = str(row["Feature"]).strip()
    inputs = str(row.get("Testcase Inputs", ""))
    steps = str(row.get("Testcase Steps", ""))
    outputs = str(row.get("Testcase Outputs", ""))

    # Folder per feature
    feature_dir = os.path.join(base_dir, feature_name.replace(' ', '_').lower())
    os.makedirs(feature_dir, exist_ok=True)

    # --- Prompt for LLM with Templates Reference ---
    prompt = f"""
You are a UVM SystemVerilog expert.
Use the following reference templates to maintain coding style and structure:

{template_reference}

Now generate a feature-specific UVM test for the feature below:
Feature: {feature_name}
Inputs: {inputs}
Steps: {steps}
Expected Outputs: {outputs}

Requirements:
- Create a UVM sequence sending transactions.
- Create a UVM test class starting the sequence.
- Add scoreboard checks for expected outputs.
- Follow the style in the reference templates.
- Output valid SystemVerilog only.
"""

    try:
        response = model.generate_content(prompt)
        testcase_code = response.candidates[0].content.parts[0].text if response.candidates else ""

        # Save test file
        filename = os.path.join(feature_dir, f"{feature_name.replace(' ', '_').lower()}_test.sv")
        with open(filename, "w") as f:
            f.write(testcase_code)

        print(f"Generated: {filename}")

    except Exception as e:
        print(f"Error generating testcase for {feature_name}: {e}")
