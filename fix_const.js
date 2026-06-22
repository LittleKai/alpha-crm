const fs = require('fs');
let code = fs.readFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', 'utf8');

code = code.replace(/const Icon\(Icons\.smart_toy_outlined, color: AppColors\.primary\),/, 'Icon(Icons.smart_toy_outlined, color: AppColors.primary),');

fs.writeFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', code);
console.log('done');