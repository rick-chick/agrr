module.exports = {
  testMatch: ['<rootDir>/test/javascript/**/*_test.js'],
  transform: {
    '^.+\\.js$': 'babel-jest'
  }
};
