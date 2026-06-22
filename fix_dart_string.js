const fs = require('fs');
let code = fs.readFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', 'utf8');

code = code.replace(
  /final labelText = \`\$\{isTokenIn \? "Token vào" : "Token ra"}: \$\{_fmt\(spot\.y\)\}\`;/,
  "final labelText = '${isTokenIn ? \"Token vào\" : \"Token ra\"}: ${_fmt(spot.y)}';"
);

fs.writeFileSync('lib/features/dashboard/presentation/widgets/ai_token_usage_card.dart', code);
console.log('done');