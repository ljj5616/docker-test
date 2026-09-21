module.exports = {
  apps: [{
    name: 'docker-test',
    cwd: __dirname,
    script: 'src/server.js',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      HOST: '0.0.0.0',
      PORT: 3000,
      DATA_DIR: require('node:path').join(__dirname, 'data'),
    },
  }],
};
