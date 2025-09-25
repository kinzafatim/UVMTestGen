import google.generativeai as genai
import pandas as pd
import os

# --- Gemini API Configuration ---
GEMINI_API_KEY = "AIzaSyA3ScUBOwzI9-SGmMblGGyb1kKA0mphm5A"
genai.configure(api_key=GEMINI_API_KEY)

# --- Input Files ---
xlsx_file = "AndGate_verifcationplan_multisheet.xlsx"
df = pd.read_excel(xlsx_file, sheet_name="Verification Plan")

# Combine entire verification plan into one description for the DUT
dut_info = "\n".join([str(row.to_dict()) for _, row in df.iterrows()])

# --- Templates Directory ---
templates_dir = "Templates"
base_dir = "And_Gate_testcases_Only"
os.makedirs(base_dir, exist_ok=True)

# --- Load Templates ---
def load_template(filename):
    path = os.path.join(templates_dir, filename)
    if os.path.exists(path):
        with open(path, "r") as f:
            return f.read()
    return ""

seq_item_template = load_template("template_seq_item.sv")
sequence_template = load_template("template_sequence.sv")
test_template = load_template("template_test.sv")

# --- LLM Model ---
model = genai.GenerativeModel("gemini-2.0-flash")

# --- Prompts for full DUT testcases ---
seq_item_prompt = f"""
You are a UVM SystemVerilog expert.
Using the style below, generate ONE UVM sequence item for the ENTIRE DUT.
Template style:
{seq_item_template}

DUT Verification Plan:
{dut_info}

Output valid SystemVerilog only.
"""

sequence_prompt = f"""
You are a UVM SystemVerilog expert.
Using the style below, generate ONE UVM sequence for the ENTIRE DUT.
Template style:
{sequence_template}

DUT Verification Plan:
{dut_info}

Output valid SystemVerilog only.
"""

test_prompt = f"""
You are a UVM SystemVerilog expert.
Using the style below, generate ONE UVM test class for the ENTIRE DUT.
Template style:
{test_template}

DUT Verification Plan:
{dut_info}

Output valid SystemVerilog only.
"""

# --- Generate Code for Entire DUT ---
try:
    seq_item_code = model.generate_content(seq_item_prompt).candidates[0].content.parts[0].text
    sequence_code = model.generate_content(sequence_prompt).candidates[0].content.parts[0].text
    test_code = model.generate_content(test_prompt).candidates[0].content.parts[0].text

    # Save each file separately
    with open(os.path.join(base_dir, "and_gate_seq_item.sv"), "w") as f:
        f.write(seq_item_code)

    with open(os.path.join(base_dir, "and_gate_sequence.sv"), "w") as f:
        f.write(sequence_code)

    with open(os.path.join(base_dir, "and_gate_test.sv"), "w") as f:
        f.write(test_code)

    print("\n✅ Testcase files generated successfully!")

except Exception as e:
    print(f"Error generating DUT testcases: {e}")
