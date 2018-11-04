import React from "react";
import ReactDOM from "react-dom";

import './style.scss';
import 'typeface-roboto';

import { createMuiTheme } from '@material-ui/core/styles';
import Button from '@material-ui/core/Button';
import MuiThemeProvider from '@material-ui/core/styles/MuiThemeProvider';

import AccessAlarmIcon from '@material-ui/icons/AccessAlarm';


import TesterUIHeader from './testerui_header';

const aColorsSolarized = {
  base03: '#002b36',
  base02: '#073642',
  base01: '#586e75',
  base00: '#657b83',
  base0:  '#839496',
  base1:  '#93a1a1',
  base2:  '#eee8d5',
  base3:  '#fdf6e3',
  yellow: '#b58900',
  orange: '#cb4b16',
  red:    '#dc322f',
  magenta:'#d33682',
  violet: '#6c71c4',
  blue:   '#268bd2',
  cyan:   '#2aa198',
  green:  '#859900'
}
const themeSolarizedDark = createMuiTheme({
  typography: {
    useNextVariants: true,
  },
  palette: {
    common: {
      black: "#000000",
      white: "#ffffff"
    },
    background: {
      paper: aColorsSolarized['base02'],
      default: aColorsSolarized['base03']
    },
    primary: {
      light: aColorsSolarized['base0'],
      main: aColorsSolarized['base00'],
      dark: aColorsSolarized['base01'],
      contrastText: aColorsSolarized['green']
    },
    secondary: {
      light: aColorsSolarized['cyan'],
      main: aColorsSolarized['blue'],
      dark: aColorsSolarized['violet'],
      contrastText: aColorsSolarized['yellow']
    },
    error: {
      light: aColorsSolarized['orange'],
      main: aColorsSolarized['red'],
      dark: aColorsSolarized['violet'],
      contrastText: aColorsSolarized['magenta']
    },
    text: {
      primary: aColorsSolarized['base1'],
      secondary: aColorsSolarized['base01'],
      disabled: aColorsSolarized['base00'],
      hint: aColorsSolarized['base1']
    }
  }
});

ReactDOM.render(<MuiThemeProvider theme={themeSolarizedDark}><TesterUIHeader /></MuiThemeProvider>, document.getElementById("index"));
