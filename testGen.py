import google.generativeai as genai
import pandas as pd
import os


GEMINI_API_KEY = "AIzaSyA3ScUBOwzI9-SGmMblGGyb1kKA0mphm5A"
genai.configure(api_key=GEMINI_API_KEY)


xlsx_file = "Vps/MiniUart_verifcationplan.xlsx"
df = pd.read_excel(xlsx_file, sheet_name="Verification Plan")


templates_dir = "Templates"
base_dir = "uvm_testcases_1"
os.makedirs(base_dir, exist_ok=True)

# template Files as Reference
def load_template(filename):
    path = os.path.join(templates_dir, filename)
    if os.path.exists(path):
        with open(path, "r") as f:
            return f.read()
    return ""

base_test_template = load_template("template_test.sv")
base_seq_template = load_template("template_sequence.sv")
seq_item_template = load_template("template_seq_item.sv")

# Combine all templates for reference
template_reference = f"""
// ---------- Reference Templates ----------
{base_test_template}

{base_seq_template}

{seq_item_template}
// ---------- End Templates ----------
"""

model = genai.GenerativeModel("gemini-2.0-flash")

# Collect all testcases in one file
all_testcases = []

for _, row in df.iterrows():
    # Convert the entire row to a dictionary (all columns included)
    feature_data = row.to_dict()

    # Extract feature name for labeling sections in the final file
    feature_name = str(row.get("Feature", "Unnamed_Feature")).strip()

    # Pass the entire feature dictionary to LLM
    prompt = f"""
You are a UVM SystemVerilog expert.
Use the following reference templates to maintain coding style and structure:

{template_reference}

Below is the full set of details from the verification plan for one feature:
{feature_data}

Requirements:
- Create a UVM sequence sending transactions.
- Create a UVM test class starting the sequence.
- Add scoreboard checks based on 'Scoreboard and Checker'.
- Use 'Constraints' and 'Randomization Constraints' for sequence randomization.
- Ensure coverage goals from 'Coverage Method', 'Sequences Coverage', and 'Register Value Coverage' are met.
- Follow the style in the reference templates.
- Output valid SystemVerilog only.
- Include all tests from 'Test Cases' in the generated file.
"""

    try:
        response = model.generate_content(prompt)
        testcase_code = response.candidates[0].content.parts[0].text if response.candidates else ""

        all_testcases.append(f"// ----- Testcase for {feature_name} -----\n{testcase_code}\n")

        print(f"Generated testcase for: {feature_name}")

    except Exception as e:
        print(f"Error generating testcase for {feature_name}: {e}")


# all testcases in a single file
final_test_file = os.path.join(base_dir, "all_features_testcases.sv")
with open(final_test_file, "w") as f:
    f.write("\n\n".join(all_testcases))

print(f"\n✅ All testcases saved in: {final_test_file}")
