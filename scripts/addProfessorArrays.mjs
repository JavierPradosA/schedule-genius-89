import fs from 'node:fs';

let text = fs.readFileSync('src/data/demoData.ts', 'utf8');

text = text.replace(/professor: ("[^"]*"), type:/g, (_match, professorLiteral) => {
  const professors = JSON.parse(professorLiteral)
    .split(',')
    .map((name) => name.trim())
    .filter(Boolean);

  return `professor: ${professorLiteral}, professors: ${JSON.stringify(professors)}, type:`;
});

fs.writeFileSync('src/data/demoData.ts', text, 'utf8');
console.log('Añadidos arrays professors a demoData.ts');
