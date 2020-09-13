const webpack = require('webpack');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');

module.exports = {
  entry: {
    main: './assets/javascripts/main.ts',
  },

  resolve: {
    modules: [
      __dirname + '/assets/javascripts',
      __dirname + '/assets/stylesheets',
      __dirname + '/node_modules',
    ],
    extensions: ['.js', '.ts', '.css', '.scss']
  },

  output: {
    path: __dirname + '/.tmp/dist',
    filename: 'assets/javascripts/[name].js',
    chunkFilename: 'assets/javascripts/[id].js',
  },

  module: {
    rules: [
      {
        test: /\.ts$/,
        exclude: /node_modules/,
        use: {
          loader: 'ts-loader',
        }
      },
      {
        test: /\.(sa|sc|c)ss$/,
        use: [
          {
            loader: MiniCssExtractPlugin.loader,
            options: {
              hmr: process.env.NODE_ENV === 'development',
            },
          },
          'css-loader',
          'postcss-loader',
          'sass-loader',
        ],
      },
      {
        test: /\.(woff|woff2|eot|otf|ttf|svg)$/,
        use: {
          loader: 'file-loader',
          options: {
            outputPath: '/assets/webfonts',
            publicPath: '/assets/webfonts'
          }
        }
      },
    ]
  },

  plugins: [
    new MiniCssExtractPlugin({
      filename: 'assets/stylesheets/[name].css',
      chunkFilename: 'assets/stylesheets/[id].css',
    }),
    new CleanWebpackPlugin(),
  ],
};
