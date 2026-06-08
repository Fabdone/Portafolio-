const express = require('express');
const mysql = require('mysql2/promise');

const app = express();
app.use(express.json());

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'cdo_clinic',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

app.put('/api/usuarios/perfil/:id', async (req, res) => {
  const { avatar_url, preferencia_tema } = req.body;
  const { id } = req.params;

  try {
    const [result] = await pool.execute(
      'UPDATE usuarios SET avatar_url = ?, preferencia_tema = ? WHERE id_usuario = ?',
      [avatar_url ?? null, preferencia_tema ?? null, id]
    );

    return res.json({
      ok: true,
      affectedRows: result.affectedRows,
      avatar_url: avatar_url ?? null,
      preferencia_tema: preferencia_tema ?? null,
    });
  } catch (error) {
    console.error('Error updating usuario perfil:', error);
    return res.status(500).json({ ok: false, error: 'Error al actualizar el perfil del usuario.' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
