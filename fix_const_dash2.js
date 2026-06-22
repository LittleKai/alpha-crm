const fs = require('fs');
let code = fs.readFileSync('lib/features/dashboard/presentation/screens/dashboard_screen.dart', 'utf8');

code = code.replace(/const SizedBox\(\s*width: 20,\s*height: 20,\s*child: CircularProgressIndicator\(\s*strokeWidth: 2\.5,\s*valueColor: AlwaysStoppedAnimation<Color>\(AppColors\.primary\),\s*\),\s*\),/g, 'SizedBox(\n            width: 20,\n            height: 20,\n            child: CircularProgressIndicator(\n              strokeWidth: 2.5,\n              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),\n            ),\n          ),');

fs.writeFileSync('lib/features/dashboard/presentation/screens/dashboard_screen.dart', code);
console.log('done');