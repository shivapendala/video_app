const authService = require('../backend/src/services/auth.service');

async function testAuth() {
  try {
    console.log('--- Testing Admin Login via AuthService ---');
    const res1 = await authService.login({ email: 'admin@gmail.com', password: 'admin123' });
    console.log('✅ Admin Login (admin@gmail.com) Success! User:', res1.user);
    console.log('Access Token Length:', res1.accessToken.length);

    console.log('\n--- Testing Admin Login via Username "admin" ---');
    const res2 = await authService.login({ email: 'admin', password: 'admin123' });
    console.log('✅ Admin Login (username "admin") Success! User:', res2.user);

  } catch(err) {
    console.error('❌ AuthService Login Error:', err.message);
  }
}

testAuth();
