const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');

module.exports = {
  entry: path.join(__dirname, 'src', 'index.js'),

  output: {
    path: path.resolve(__dirname, "targets", "www")
  },

  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader"
        }
      },
      {
        test: /\.css$/,
        use: ['style-loader', 'css-loader']
      },
      {
        test: /\.(woff(2)?|ttf|eot)(\?v=\d+\.\d+\.\d+)?$/,
        type: 'asset'
      },
      {
        test: /\.(png|jpg|gif|svg)$/,
        type: 'asset'
      },
      {
        test: /get_version.js$/,
        use: [
          {
            loader: 'val-loader',
          },
        ],
      },
      {
        test: /get_vcsversion.js$/,
        use: [
          {
            loader: 'val-loader',
          },
        ],
      }
    ]
  },
  plugins: [
    new HtmlWebpackPlugin({
      favicon: path.join(__dirname,'src','images','muhkuh.svg'),
      template: path.join(__dirname,'src','index.html')
    })
  ]
};
