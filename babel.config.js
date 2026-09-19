module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: [
    // WatermelonDB models use legacy decorators (@field, @date, @relation).
    ['@babel/plugin-proposal-decorators', { legacy: true }],
    // zod v4 ships `export * as ns from '...'`, which the React Native preset
    // does not transform on its own.
    '@babel/plugin-transform-export-namespace-from',
  ],
};
