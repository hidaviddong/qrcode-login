import db from "./index.js";

async function initDB() {
    try {
        const removeAllTables = `
        DROP TABLE IF EXISTS qr_sessions;
        DROP TABLE IF EXISTS users;
        `;
        await db.query(removeAllTables, [])
        const createUsersTable = `
        CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        `;

        const createQrSessionsTable = `
        CREATE TABLE IF NOT EXISTS qr_sessions (
        id SERIAL PRIMARY KEY,
        token VARCHAR(255) UNIQUE NOT NULL,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        status VARCHAR(50) DEFAULT 'pending',
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        `;

        await db.query(createUsersTable, [])
        await db.query(createQrSessionsTable, [])

        const insertUser = `
        INSERT INTO users (email, password_hash) VALUES ($1, $2)
        `;
        await db.query(insertUser, ['1', '1'])
    
        console.log('Database initialized successfully')
        await db.end()
    } catch (error) {
        console.error('Database initialization failed:', error)
        await db.end()
        process.exit(1)
    }
    
}

initDB()