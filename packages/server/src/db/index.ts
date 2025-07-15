import { Pool } from 'pg'
import 'dotenv/config'

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    port: parseInt(process.env.DB_PORT || '5432'),
    password: process.env.DB_PASSWORD,
})

export default {
    query: (text: string, params: any[]) => pool.query(text, params),
    end: () => pool.end()
}

