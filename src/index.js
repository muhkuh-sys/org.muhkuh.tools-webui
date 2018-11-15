import React from "react";
import ReactDOM from "react-dom";

import './style.scss';
import 'typeface-roboto';
import 'typeface-roboto-mono';

import { transform } from 'babel-standalone';
import { createMuiTheme } from '@material-ui/core/styles';
import Button from '@material-ui/core/Button';
import CircularProgress from '@material-ui/core/CircularProgress';
import CssBaseline from '@material-ui/core/CssBaseline';
import MuiThemeProvider from '@material-ui/core/styles/MuiThemeProvider';
import Tabs from '@material-ui/core/Tabs';
import Tab from '@material-ui/core/Tab';
import Typography from '@material-ui/core/Typography';

import AccessAlarmIcon from '@material-ui/icons/AccessAlarm';


import TesterUIHeader from './testerui_header';
import TesterUILog from './testerui_log';
import TesterUISummary from './testerui_summary';
import TesterUITheme from './testerui_theme';


const TesterAppState_Idle = 0;
const TesterAppState_Connecting = 1;
const TesterAppState_Connected = 2;
const TesterAppState_ConnectionClosed = 3;
const TesterAppState_ErrorWebsocketNotSupported = 4;
const TesterAppState_ErrorFailedToCreateWebsocket = 5;
const TesterAppState_ErrorFailedToConnect = 6;

const TesterAppTab_Interaction = 0;
const TesterAppTab_TestLog = 1;
const TesterAppTab_SystemLog = 2;

class TesterApp extends React.Component {
  constructor(props) {
    super(props);
    var _tState = TesterAppState_Idle;
    if( 'WebSocket' in window === false ) {
      _tState = TesterAppState_ErrorWebsocketNotSupported;
    }
    this.state = {
      tState: _tState,
      uiActiveTab: TesterAppTab_Interaction,

      tTest_Title: null,
      tTest_Subtitle: null,
      tTest_fHasSerial: false,
      tTest_uiFirstSerial: 0,
      tTest_uiLastSerial: 0,

      tRunningTest_uiCurrentSerial: null,

      tUI_CowIconSize: '3em',
      tUI_fnInteraction: null
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
    this.tSocket.send('ReqInit')
    this.setState({ tState: TesterAppState_Connected });
  }

  socketMessage(tEvent) {
    console.debug("WebSocket message received:", tEvent.data);

    let tJson = JSON.parse(tEvent.data);
    let strId = tJson.id;
    if( strId=='SetTitle' ) {
      this.setState({
        tTest_Title: tJson.title,
        tTest_Subtitle: tJson.subtitle,
        tTest_fHasSerial: tJson.hasSerial,
        tTest_uiFirstSerial: tJson.firstSerial,
        tTest_uiLastSerial: tJson.lastSerial
      });
    } else if( strId=='SetInteraction' ) {
      /* Translate the received code with babel. */
      let tBabel = transform(
        tJson.jsx,
        {
          filename: 'dynamic_loaded.jsx',
          presets: ['es2015', 'stage-2' , 'react']
        }
      );
      let tCode = tBabel.code + "\nreturn Interaction;\n";
      let tFn = new Function('React', tCode);

      this.setState({
        uiActiveTab: TesterAppTab_Interaction,
        tUI_fnInteraction: tFn
      });
    }
  }

  handleTabChange = (tEvent, uiValue) => {
    this.setState({ uiActiveTab: uiValue });
  };


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
        _socket.onmessage = function(event) { _this.socketMessage(event) };
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

  handleCowClick = (uiIndex) => {
    console.log("haha");
    console.log(uiIndex);
  }

  render() {
    let tTabContents = '';
    if( this.state.uiActiveTab===TesterAppTab_Interaction ) {
      if( this.state.tState===TesterAppState_Idle ) {
        tTabContents = (
          <div>
            <Typography align="center" variant="h2" gutterBottom>Welcome to the TesterUI.</Typography>
            <Typography align="center" variant="subtitle1">Please wait until the application is initialized.</Typography>
          </div>
        );
      } else if( this.state.tState===TesterAppState_Connecting ) {
        tTabContents = (
          <div>
            <Typography align="center" variant="h2" gutterBottom>Connecting...</Typography>
            <CircularProgress variant="indeterminate" />
          </div>
        );
      } else if( this.state.tState===TesterAppState_Connected ) {
        if( this.state.tUI_fnInteraction===null ) {
          tTabContents = (
            <Typography align="center" variant="h4" gutterBottom>No interaction...</Typography>
          );
        } else {
          tTabContents = React.createElement(this.state.tUI_fnInteraction(React));
          console.debug(tTabContents);
        }
      } else if( this.state.tState===TesterAppState_ConnectionClosed ) {
        tTabContents = (
          <Typography align="center" variant="h2" gutterBottom>The connection was closed.</Typography>
        );
      } else if( this.state.tState===TesterAppState_ErrorWebsocketNotSupported ) {
        tTabContents = (
          <div>
            <Typography align="center" variant="h2" gutterBottom>Websocket is not supported by your browser!</Typography>
            <Typography align="center" variant="subtitle1">Install the latest <a href="https://www.mozilla.org/en-US/firefox/new/">Firefox</a>.</Typography>
          </div>
        );
      } else if( this.state.tState===TesterAppState_ErrorFailedToCreateWebsocket ) {
        tTabContents = (
          <div>
            <Typography align="center" variant="h2" gutterBottom>Failed to create the websocket!</Typography>
          </div>
        );
      } else if( this.state.tState===TesterAppState_ErrorFailedToConnect ) {
        tTabContents = (
          <div>
            <Typography align="center" variant="h2" gutterBottom>Failed to connect!</Typography>
          </div>
        );
      } else {
        tTabContents = (
          <div>
            <Typography align="center" variant="h2" gutterBottom>Invalid state!</Typography>
            <Typography align="center" variant="subtitle1">{this.state.tState}</Typography>
          </div>
        );
      }
    } else if( this.state.uiActiveTab===TesterAppTab_TestLog ) {
      tTabContents = (
        <TesterUILog />
      );
    } else if( this.state.uiActiveTab===TesterAppTab_SystemLog ) {
      tTabContents = (
        <Typography align="center" variant="h2" gutterBottom>System log</Typography>
      );
    }

    return (
      <MuiThemeProvider theme={TesterUITheme}>
        <CssBaseline>
          <div id='TesterApp'>
            <div id='TesterHeader'>
              <TesterUIHeader strTitle={this.state.tTest_Title} strSubtitle={this.state.tTest_Subtitle} fHasSerial={this.state.tTest_fHasSerial} uiFirstSerial={this.state.tTest_uiFirstSerial} uiLastSerial={this.state.tTest_uiLastSerial} />
              <TesterUISummary fHasSerial={this.state.tTest_fHasSerial} uiCurrentSerial={this.state.tRunningTest_uiCurrentSerial} strIconSize={this.state.tUI_CowIconSize} theme={TesterUITheme} handleCowClick={this.handleCowClick} />
              <div id='TesterTabs'>
                <Tabs value={this.state.uiActiveTab} onChange={this.handleTabChange}>
                  <Tab label="Interaction" />
                  <Tab label="Test Log" />
                  <Tab label="System Log" />
                </Tabs>
              </div>
            </div>
            <div id='TesterTabContents'>
              {tTabContents}
            </div>
          </div>
        </CssBaseline>
      </MuiThemeProvider>
    );
  }
}


ReactDOM.render(<TesterApp />, document.getElementById("index"));
