import re

file_path = r'D:\Dev\NodeJS\alpha-studio\tools\alpha-crm\lib\features\dashboard\presentation\screens\dashboard_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("? const Center(\n              child: CircularProgressIndicator(color: AppColors.primary),\n            )", "? Center(\n              child: CircularProgressIndicator(color: AppColors.primary),\n            )")

content = content.replace("valueColor: new AlwaysStoppedAnimation<Color>(AppColors.primary),", "valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),")

content = content.replace("const SizedBox(\n                      width: 14,\n                      height: 14,\n                      child: CircularProgressIndicator(\n                        strokeWidth: 2,\n                        color: AppColors.primary,\n                      ),\n                    )", "SizedBox(\n                      width: 14,\n                      height: 14,\n                      child: CircularProgressIndicator(\n                        strokeWidth: 2,\n                        color: AppColors.primary,\n                      ),\n                    )")


with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
