import readline from 'readline';
import { getMachineFingerprint, saveAgentCredentials } from './agent-identity.js';
import { registerDevice } from './cloud-api.js';

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query: string): Promise<string> {
  return new Promise((resolve) => rl.question(query, resolve));
}

async function main() {
  console.log('\n=========================================');
  console.log(' Alpha CRM — Device Registration Client ');
  console.log('=========================================\n');

  try {
    let jwt = process.env.USER_JWT;
    if (!jwt) {
      jwt = await question('Nhập JWT Token của tài khoản Alpha Studio: ');
      jwt = jwt.trim();
    }

    if (!jwt) {
      console.error('❌ Lỗi: JWT Token không được rỗng.');
      rl.close();
      process.exit(1);
    }

    let displayName = process.env.CRM_DEVICE_NAME || osDisplayName();
    if (!process.env.CRM_DEVICE_NAME) {
      const inputName = await question(`Tên thiết bị hiển thị (mặc định: "${displayName}"): `);
      if (inputName.trim()) {
        displayName = inputName.trim();
      }
    }

    const fingerprint = getMachineFingerprint();
    console.log(`\nGenerating stable machine fingerprint...`);
    console.log(`Fingerprint hash: ${fingerprint}`);

    console.log(`\nConnecting to Cloud Backend to register device...`);
    const result = await registerDevice(jwt, displayName, fingerprint);

    console.log('\n✅ Đăng ký thành công!');
    console.log(`Device ID: ${result.deviceId}`);
    console.log(`Agent Secret: ************ (Redacted)`);

    const saved = saveAgentCredentials(result.deviceId, result.agentSecret);
    if (saved) {
      console.log('\n🎉 Hoàn tất! Thiết bị của bạn đã sẵn sàng chạy ở chế độ Agent.');
    } else {
      console.error('\n❌ Lỗi: Không thể lưu thông tin xác thực thiết bị.');
    }
  } catch (err: any) {
    console.error('\n❌ Đăng ký thiết bị thất bại:', err.message);
  } finally {
    rl.close();
  }
}

function osDisplayName(): string {
  // Simple fallback OS description
  return `Windows ${process.arch} (${process.env.COMPUTERNAME || 'Agent PC'})`;
}

main();
