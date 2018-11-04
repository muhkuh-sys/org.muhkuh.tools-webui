import React from "react";
import ReactDOM from "react-dom";

import './style.scss';
import 'typeface-roboto';

import { createMuiTheme } from '@material-ui/core/styles';
import Button from '@material-ui/core/Button';
import CircularProgress from '@material-ui/core/CircularProgress';
import CssBaseline from '@material-ui/core/CssBaseline';
import MuiThemeProvider from '@material-ui/core/styles/MuiThemeProvider';
import Typography from '@material-ui/core/Typography';

import AccessAlarmIcon from '@material-ui/icons/AccessAlarm';


import TesterUIHeader from './testerui_header';

/* See here for details: https://ethanschoonover.com/solarized/ */
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


const TesterAppState_Idle = 0;
const TesterAppState_Connecting = 1;
const TesterAppState_Connected = 2;
const TesterAppState_ConnectionClosed = 3;
const TesterAppState_ErrorWebsocketNotSupported = 4;
const TesterAppState_ErrorFailedToCreateWebsocket = 5;
const TesterAppState_ErrorFailedToConnect = 6;

class TesterApp extends React.Component {
  constructor(props) {
    super(props);
    var _tState = TesterAppState_Idle;
    if( 'WebSocket' in window === false ) {
      _tState = TesterAppState_ErrorWebsocketNotSupported;
    }
    this.state = {
      tState: _tState
    };
    this.tSocket = null;
  }

  socketClosed(tEvent) {
    console.log("WebSocket is closed now.");
    if( this.state.tState==TesterAppState_Connected ) {
      this.setState({ tState: TesterAppState_ConnectionClosed });
    }
    else
    {
      this.setState({ tState: TesterAppState_ErrorFailedToConnect });
    }
  }

  socketError(tEvent) {
    console.error("WebSocket error observed:", tEvent);
  }

  socketOpen(tEvent) {
    console.log("WebSocket is open now.");
    this.tSocket.send('hi')
    this.setState({ tState: TesterAppState_Connected });
  }

  componentDidMount() {
    /* Create the websocket if it does not exist yet. */
    if( this.state.tState===TesterAppState_Idle && this.tSocket===null )
    {
      var _socket = new WebSocket('ws://127.0.0.1:12345', 'echo');
      if( _socket===null ) {
        this.setState({ tState: TesterAppState_ErrorFailedToCreateWebsocket });
      } else {
        /* Pass this class to the callback functions as a closure. */
        var _this = this;
        _socket.onclose = function(event) { _this.socketClosed(event) };
        _socket.onerror = function(event) { _this.socketError(event) };
        _socket.onmessage = function(event) {
          console.debug("WebSocket message received:", event.data);
        };
        _socket.onopen = function(event) { _this.socketOpen(event) };

        this.tSocket = _socket;

        /* The socket is now connecting. */
        this.setState({ tState: TesterAppState_Connecting });
      }
    }
  }

  componentWillUnmount() {
    /* Close the websocket. */
    if( this.tSocket!==null )
    {
      this.tSocket.close();
    }
  }

  render() {
    var eInner = ''
    if( this.state.tState===TesterAppState_Idle ) {
      eInner = (
        <div>
          <Typography align="center" variant="h2" gutterBottom>Welcome to the TesterUI.</Typography>
          <Typography align="center" variant="subtitle1">Please wait until the application is initialized.</Typography>
        </div>
      );
    } else if( this.state.tState===TesterAppState_Connecting ) {
      eInner = (
        <div>
          <Typography align="center" variant="h2" gutterBottom>Connecting...</Typography>
          <CircularProgress variant="indeterminate" />
        </div>
      );
    } else if( this.state.tState===TesterAppState_Connected ) {
      eInner = (
        <Typography align="center" variant="h2" gutterBottom>Yay! Websocket is connected.</Typography>
      );
    } else if( this.state.tState===TesterAppState_ConnectionClosed ) {
      eInner = (
        <Typography align="center" variant="h2" gutterBottom>The connection was closed.</Typography>
      );
    } else if( this.state.tState===TesterAppState_ErrorWebsocketNotSupported ) {
      eInner = (
        <div>
          <Typography align="center" variant="h2" gutterBottom>Websocket is not supported by your browser!</Typography>
          <Typography align="center" variant="subtitle1">Install the latest <a href="https://www.mozilla.org/en-US/firefox/new/">Firefox</a>.</Typography>
        </div>
      );
    } else if( this.state.tState===TesterAppState_ErrorFailedToCreateWebsocket ) {
      eInner = (
        <div>
          <Typography align="center" variant="h2" gutterBottom>Failed to create the websocket!</Typography>
        </div>
      );
    } else if( this.state.tState===TesterAppState_ErrorFailedToConnect ) {
      eInner = (
        <div>
          <Typography align="center" variant="h2" gutterBottom>Failed to connect!</Typography>
        </div>
      );
    } else {
      eInner = (
        <div>
          <Typography align="center" variant="h2" gutterBottom>Invalid state!</Typography>
          <Typography align="center" variant="subtitle1">{this.state.tState}</Typography>
        </div>
      );
    }

    return (
      <MuiThemeProvider theme={themeSolarizedDark}>
        <CssBaseline>
          {eInner}
        </CssBaseline>
      </MuiThemeProvider>
    );
  }
}


ReactDOM.render(<TesterApp />, document.getElementById("index"));
