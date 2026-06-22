const fs = require('fs');
let code = fs.readFileSync('lib/features/dashboard/presentation/screens/dashboard_screen.dart', 'utf8');

code = code.replace(/crossAxisSpacing: AppSpacing\.m,\s*mainAxisSpacing: AppSpacing\.m,\s*mainAxisExtent: 94,/g, 'crossAxisSpacing: AppSpacing.m,\n                  mainAxisSpacing: AppSpacing.m,\n                  mainAxisExtent: 100,');

fs.writeFileSync('lib/features/dashboard/presentation/screens/dashboard_screen.dart', code);
console.log('done');