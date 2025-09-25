import google.generativeai as genai
import pandas as pd
import os

GEMINI_API_KEY = ""  # <-- replace with your real key
genai.configure(api_key=GEMINI_API_KEY)

xlsx_file = "AndGate_verifcationplan_multisheet.xlsx"
base_dir = "UVM_TestBench_For_And_Gate"
os.makedirs(base_dir, exist_ok=True)

model = genai.GenerativeModel("gemini-2.0-flash")

# Load all sheets & combine all rows into one big dataframe
xls = pd.ExcelFile(xlsx_file)
all_sheets = xls.sheet_names
df_list = [pd.read_excel(xlsx_file, sheet_name=s) for s in all_sheets]
df = pd.concat(df_list, ignore_index=True)

# combine all rows to one dictionary for LLM
all_features = df.to_dict(orient="records")

# file to generate
uvm_files = [
    "and_sequence_item.sv", "and_sequence.sv", "and_sequencer.sv",
    "and_driver.sv", "and_monitor.sv", "and_agent.sv", "and_env.sv",
    "and_scoreboard.sv", "and_coverage.sv", "and_test.sv",
    "interface.sv", "design.sv", "tb_pkg.sv", "testbench.sv"
]

# prompt one full testbench using all features
prompt = f"""
You are a UVM SystemVerilog expert.

Below is the full set of details from the verification plan for the entire AND Gate design:
{all_features}

Requirements:
- Generate ONE complete UVM testbench for the entire design with the following files: {uvm_files}
- Use *all* features, test cases, coverage goals, and constraints from the verification plan.
- Put sequences for each feature inside and_sequence.sv
- Put all coverage items inside and_coverage.sv
- Put all tests inside and_test.sv
- Follow proper UVM component hierarchy and coding style.
- Output one file at a time, starting with // FILE: <filename>
"""

try:
    response = model.generate_content(prompt)
    if not response.candidates:
        print("!! No content generated")
        exit(1)

    code_text = response.candidates[0].content.parts[0].text

    # Split by file markers and save each file
    for section in code_text.split("// FILE:"):
        section = section.strip()
        if not section:
            continue
        lines = section.split("\n", 1)
        if len(lines) < 2:
            continue
        fname, content = lines[0].strip(), lines[1]
        out_path = os.path.join(base_dir, fname)
        with open(out_path, "w") as f:
            f.write(content)

    print(f"\n✅ Complete UVM Testbench saved in: {base_dir}")

except Exception as e:
    print(f"Error generatin testbench: {e}")
