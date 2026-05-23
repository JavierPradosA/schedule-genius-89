import fs from 'node:fs';
import pg from 'pg';

const { Client } = pg;

const password = process.env.SUPABASE_DB_PASSWORD;

if (!password) {
  throw new Error('Falta SUPABASE_DB_PASSWORD.');
}

const client = new Client({
  host: 'db.hnhxfmebargwrazopmco.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password,
  ssl: { rejectUnauthorized: false },
});

await client.connect();
await client.query(fs.readFileSync('supabase/feedback_final.sql', 'utf8'));

const { rows } = await client.query(`
  select column_name, data_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'feedback_final'
  order by ordinal_position
`);

console.table(rows);
await client.end();

