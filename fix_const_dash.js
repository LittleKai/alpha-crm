const fs = require('fs');
let code = fs.readFileSync('lib/features/dashboard/presentation/screens/dashboard_screen.dart', 'utf8');

code = code.replace(/const Center\(\s*child: CircularProgressIndicator\(color: AppColors\.primary\),\s*\)/g, 'Center(\n              child: CircularProgressIndicator(color: AppColors.primary),\n            )');
code = code.replace(/const SizedBox\(\s*width: 14,\s*height: 14,\s*child: CircularProgressIndicator\(\s*strokeWidth: 2,\s*valueColor: AlwaysStoppedAnimation<Color>\(AppColors\.primary\),\s*\),\s*\)/g, 'SizedBox(\n                      width: 14,\n                      height: 14,\n                      child: CircularProgressIndicator(\n                        strokeWidth: 2,\n                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),\n                      ),\n                    )');

fs.writeFileSync('lib/features/dashboard/presentation/screens/dashboard_screen.dart', code);
console.log('done');