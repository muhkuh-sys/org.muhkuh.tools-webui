import React from 'react';

import css from './style.css';
import "@fontsource/roboto";
import "@fontsource/roboto-mono";

const muhkuh_package_version = require("./get_version");
const muhkuh_package_vcsversion = require("./get_vcsversion");

import { transform, registerPlugin, availablePlugins } from '@babel/standalone';

import { createRoot } from 'react-dom/client';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import Accordion from '@mui/material/Accordion';
import AccordionSummary from '@mui/material/AccordionSummary';
import AccordionDetails from '@mui/material/AccordionDetails';
import Button from '@mui/material/Button';
import Checkbox from '@mui/material/Checkbox';
import CircularProgress from '@mui/material/CircularProgress';
import Collapse from '@mui/material/Collapse';
import CssBaseline from '@mui/material/CssBaseline';
import Divider from '@mui/material/Divider';
import Drawer from '@mui/material/Drawer';
import FilledInput from '@mui/material/FilledInput';
import FormControl from '@mui/material/FormControl';
import FormControlLabel from '@mui/material/FormControlLabel';
import FormGroup from '@mui/material/FormGroup';
import FormHelperText from '@mui/material/FormHelperText';
import FormLabel from '@mui/material/FormLabel';
import Grid from '@mui/material/Grid';
import IconButton from '@mui/material/IconButton';
import Input from '@mui/material/Input';
import InputLabel from '@mui/material/InputLabel';
import LinearProgress from '@mui/material/LinearProgress';
import List from '@mui/material/List';
import ListItem from '@mui/material/ListItem';
import ListItemButton from '@mui/material/ListItemButton';
import ListItemIcon from '@mui/material/ListItemIcon';
import ListItemText from '@mui/material/ListItemText';
import MenuItem from '@mui/material/MenuItem';
import OutlinedInput from '@mui/material/OutlinedInput';
import Paper from '@mui/material/Paper';
import Radio from '@mui/material/Radio';
import RadioGroup from '@mui/material/RadioGroup';
import Select from '@mui/material/Select';
import SvgIcon from '@mui/material/SvgIcon';
import Switch from '@mui/material/Switch';
import Tabs from '@mui/material/Tabs';
import Tab from '@mui/material/Tab';
import TextField from '@mui/material/TextField';
import { TreeView } from '@mui/x-tree-view/TreeView';
import { TreeItem } from '@mui/x-tree-view/TreeItem';
import Typography from '@mui/material/Typography';

import Ajv from "ajv";
import ReactImageZoom from 'react-image-zoom';

import BuildCircleIcon from '@mui/icons-material/BuildCircle';
import CancelIcon from '@mui/icons-material/Cancel';
import DescriptionIcon from '@mui/icons-material/Description';
import ExpandLess from '@mui/icons-material/ExpandLess';
import ExpandMore from '@mui/icons-material/ExpandMore';
import MenuIcon from '@mui/icons-material/Menu';
import PowerIcon from '@mui/icons-material/Power';
import PowerOffIcon from '@mui/icons-material/PowerOff';
import SignalWifi0BarIcon from '@mui/icons-material/SignalWifi0Bar';
import SignalWifi1BarIcon from '@mui/icons-material/SignalWifi1Bar';
import SignalWifi2BarIcon from '@mui/icons-material/SignalWifi2Bar';
import SignalWifi3BarIcon from '@mui/icons-material/SignalWifi3Bar';
import SignalWifi4BarIcon from '@mui/icons-material/SignalWifi4Bar';
import SignalWifiConnectedNoInternet4Icon from '@mui/icons-material/SignalWifiConnectedNoInternet4';

import { Terminal } from "xterm";
import { FitAddon } from 'xterm-addon-fit';

import TesterUIHeader from './testerui_header';
import TesterUIStepMap from './testerui_stepmap';


const TesterAppState_Idle = 0;
const TesterAppState_Connecting = 1;
const TesterAppState_Connected = 2;
const TesterAppState_ConnectionClosed = 3;
const TesterAppState_FatalError = 4;
const TesterAppState_SoftError = 5;

const ConnectionState_Lost = 0;
const ConnectionState_Ok0 = 1;
const ConnectionState_Ok1 = 2;
const ConnectionState_Ok2 = 3;
const ConnectionState_Ok3 = 4;
const ConnectionState_Ok4 = 5;

const LOG_EMERG = 1;
const LOG_ALERT = 2;
const LOG_FATAL = 3;
const LOG_ERROR = 4;
const LOG_WARNING = 5;
const LOG_NOTICE = 6;
const LOG_INFO = 7;
const LOG_DEBUG = 8;
const LOG_TRACE = 9;

let TesterLog_terminal;
let TesterLog_terminal_fit;


class TesterApp extends React.Component {
  constructor(props) {
    super(props);
    let _tState = TesterAppState_Idle;
    let _tErrorMessage = null;
    if( 'WebSocket' in window === false ) {
      _tState = TesterAppState_FatalError;
      _tErrorMessage = (
        <div>
          <Typography align="center" variant="h2" gutterBottom>Websocket is not supported by your browser!</Typography>
          <Typography align="center" variant="subtitle1">Install the latest <a href="https://www.mozilla.org/en-US/firefox/new/">Firefox</a>.</Typography>
        </div>
      );
    }

    /* Initialize the server URL with NULL if it does not exist. */
    let _strServerURL = null;
    if( typeof g_CFG_strServerURL === 'string' ) {
      if( g_CFG_strServerURL === 'auto' ) {
        let wsurl = new URL("ws", location.href);
        if(wsurl.protocol === "https:") {
          wsurl.protocol = "wss";
        } else {
          wsurl = "ws";
        }
        _strServerURL = wsurl.href;
      } else {
        _strServerURL = g_CFG_strServerURL;
      }
    }
    this.m_strServerURL = _strServerURL;
    this.m_strServerProtocol = 'muhkuh-tester';

    this.tTheme = createTheme({
      palette: {
        mode: 'dark',
      }
    });

    this.state = {
      tState: _tState,
      tErrorMessage: _tErrorMessage,
      fMenuIsOpen: false,
      fMenuDocumentsOpen: false,
      enricoMode: false,

      tTest_Title: null,
      tTest_Subtitle: null,
      tTest_fHasSerial: false,
      tTest_astrTestNames: [],
      tTest_atTestStati: [],
      tTest_atDocuments: [],

      tRunningTest_uiCurrentSerial: null,
      tRunningTest_uiRunningTest: null,

      tUI_CowIconSize: '8em',
      tUI_strInteraction: null,
      tUI_tInteraction: null,

      tConnectionState: ConnectionState_Lost
    };

    this.m_tUI_strInteractionData = null;

    // A received persisence state is stored here.
    // The constructor in the interaction component accesses it with
    // the function "fnGetPersistentState".
    this.m_tInitialPersistenceState = null;

    /* All log lines combined in one string. */
    this.uiLogFilterLevel = 8;

    this.atHeartbeats = [];
    this.tHeartbeatTimer = null;

    /* No socket created yet. */
    this.tSocket = null;

    /* Provide all necessary components to parse JSX.
     * TODO: But what is necessary?
     */
    const atComponents = {
      'fnSend': this.sendInteractionMessage,
      'fnGetCurrentSerial': this.getCurrentSerial,
      'fnGetFirstSerial': this.getFirstSerial,
      'fnGetLastSerial': this.getLastSerial,
      'fnGetRunningTest': this.getRunningTest,
      'fnGetTestNames': this.getTestNames,
      'fnGetTestStati': this.getTestStati,
      'fnSetLocalTestState': this.setLocalTestState,
      'fnSetAllTestStati': this.setAllTestStati,
      'fnGetEnricoMode': this.getEnricoMode,
      'fnPersistState': this.setPersietenceState,
      'fnGetPersistentState': this.getPersistentState,
      'React': React,
      'Button': Button,
      'Checkbox': Checkbox,
      'CircularProgress': CircularProgress,
      'ExpansionPanel': Accordion,
      'ExpansionPanelSummary': AccordionSummary,
      'ExpansionPanelDetails': AccordionDetails,
      'Accordion': Accordion,
      'AccordionSummary': AccordionSummary,
      'AccordionDetails': AccordionDetails,
      'FilledInput': FilledInput,
      'FormControl': FormControl,
      'FormControlLabel': FormControlLabel,
      'FormGroup': FormGroup,
      'FormHelperText': FormHelperText,
      'FormLabel': FormLabel,
      'Grid': Grid,
      'IconButton': IconButton,
      'Input': Input,
      'InputLabel': InputLabel,
      'LinearProgress': LinearProgress,
      'List': List,
      'ListItem': ListItem,
      'ListItemIcon': ListItemIcon,
      'ListItemText': ListItemText,
      'MenuItem': MenuItem,
      'OutlinedInput': OutlinedInput,
      'Paper': Paper,
      'Radio': Radio,
      'RadioGroup': RadioGroup,
      'Select': Select,
      'SvgIcon': SvgIcon,
      'Tabs': Tabs,
      'Tab': Tab,
      'TextField': TextField,
      'TreeView': TreeView,
      'TreeItem': TreeItem,
      'Typography': Typography,
      'ReactImageZoom': ReactImageZoom,
      'Ajv': Ajv
    };
    this.atComponents = atComponents;
    /* Generate the code to assign the components. */
    let astrCode = [];
    for(const strName in atComponents) {
      astrCode.push('const ' + strName + ' = atComponents.' + strName + ';');
    }
    this.strJsxHeaderCode = astrCode.join('\n') + '\n';

    /* This is a reference to the interaction element. */
    this.tTesterInteraction = React.createRef();

    /* This is the tester terminal. */
    this.tTesterLog_terminal = TesterLog_terminal;
    this.tTesterLog_terminal_fit = TesterLog_terminal_fit;

    this.astrLogLevel = [
      '',
      'EMERG',
      'ALERT',
      'FATAL',
      'ERROR',
      'WARNING',
      'NOTICE',
      'INFO',
      'DEBUG',
      'TRACE'
    ];
    const atLogLevelAnsiColors = [
      '',              /* Log level 0 does not exist. */
      '\x1B[37;101m',  /* Log level 1: EMERG (FG: white, BG: light red) */
      '\x1B[34;101m',  /* Log level 2: ALERT (FG: blue, BG: light red) */
      '\x1B[30;101m',  /* Log level 3: FATAL (FG: black, BG: light red) */
      '\x1B[91;40m',   /* Log level 4: ERROR (FG light red, BG: black) */
      '\x1B[95;40m',   /* Log level 5: WARNING (FG: light magenta, BG: black) */
      '\x1B[96;40m',   /* Log level 6: NOTICE (FG: light cyan, BG: black) */
      '\x1B[37;40m',   /* Log level 7: INFO (FG: white, BG: black) */
      '\x1B[33;40m',   /* Log level 8: DEBUG (FG: yellow, BG: black) */
      '\x1B[92;40m'    /* Log level 9: TRACE (FG: light green, BG: black) */
    ];
    this.atLogLevelAnsiColors = atLogLevelAnsiColors;
    this.uiLastLogLevel = null;

    /* This is a regexp for matching log lines. */
    this.regexpLogLine = new RegExp('(\\d+),');

    registerPlugin('@babel/plugin-proposal-class-properties')
  }


  equalsFlatArrays(a, b) {
    return (
      Array.isArray(a) &&
      Array.isArray(b) &&
      (a.length === b.length) &&
      a.every((element, index) => element === b[index])
    );
  }


  getTimestamp() {
    const tNow = new Date();
    return tNow.getFullYear() + '-' +
           ('0' + (tNow.getMonth() + 1)).slice(-2) + '-' +
           ('0' + tNow.getDate()).slice(-2) + ' ' +
           ('0' + tNow.getHours()).slice(-2) + ':' +
           ('0' + tNow.getMinutes()).slice(-2) + ':' +
           ('0' + tNow.getSeconds()).slice(-2);
  }


  // Write a log message to the terminal or the console.
  // This routine adds the current time stamp and the name of the log level to
  // the start of the message in the form "[LEVEL] Message", for example
  // "[WARNING] Something strange happened.".
  // The message is passed to the "message" method to do the logging.
  log(uiLevel, strMessage) {
    let strLevel = '';
    if( uiLevel in this.astrLogLevel) {
      strLevel = this.astrLogLevel[uiLevel];
    }
    const strTimestamp = this.getTimestamp();
    this.message(uiLevel, strTimestamp + ' ['+strLevel+'] '+strMessage);
  }


  // Log a message.
  // If the terminal is available, add ANSI colors depending on the level and print it there.
  // Otherwise pass the message to "console.log".
  message(uiLevel, strMessage) {
    let strLevelColor = '';
    if( uiLevel in this.atLogLevelAnsiColors) {
      strLevelColor = this.atLogLevelAnsiColors[uiLevel];
    }
    this.tTesterLog_terminal.write(strLevelColor+strMessage+'\x1B[0m\n');
  }


  socketClosed(tEvent) {
    console.log("WebSocket is closed now.");
    if( this.state.tState==TesterAppState_Connected ) {
      this.setState({
        tState: TesterAppState_ConnectionClosed,
        tConnectionState: ConnectionState_Lost
      });
    }
    else
    {
      const tMsg = (
        <div>
          <Typography align="center" variant="h2" gutterBottom>Failed to connect!</Typography>
        </div>
      );
      this.setState({
        tState: TesterAppState_SoftError,
        tErrorMessage: tMsg
      });
    }
  }


  socketError(tEvent) {
    console.error("WebSocket error observed:", tEvent);
  }


  socketOpen(tEvent) {
    console.log("WebSocket is open now.");
    const strJson = JSON.stringify({id: 'ReqInit'});
    this.tSocket.send(strJson);

    // Assume an excellent connection and fake the last 4 heartbeats.
    // The timestamp is in milliseconds. Convert it to seconds.
    const ulTimestampS = Date.now() / 1000;
    this.atHeartbeats.push(ulTimestampS-6);
    this.atHeartbeats.push(ulTimestampS-4);
    this.atHeartbeats.push(ulTimestampS-2);
    this.atHeartbeats.push(ulTimestampS);

    this.setState({
      tState: TesterAppState_Connected,
      tConnectionState: ConnectionState_Ok4
    });
  }


  socketMessage(tEvent) {
//    console.debug("WebSocket message received:", tEvent.data);

    try {
      let tJson = JSON.parse(tEvent.data);
      let strId = tJson.id;
      switch(strId) {
      case 'State':
        this.onMessage_State(tJson);
        break;

      case 'Log':
        this.onMessage_Log(tJson);
        break;

      case 'Heartbeat':
        this.onMessage_Heartbeat();
        break;

      default:
        console.error('Received unknown message id:', strId);
      }
    } catch(error) {
      console.error("Received malformed JSON:", error, tEvent.data);
    }
  }


  createInteraction(strJSX) {
    let tElement = null;

    let tBabel = null;
    try {
      tBabel = transform(
        strJSX,
        {
          filename: 'dynamic_loaded.jsx',
          presets: ['env', 'react'],
          plugins: [
            [ availablePlugins["proposal-class-properties"], { decoratorsBeforeExport: true } ]
          ]
        }
      );
    } catch(error) {
      console.error('Failed to translate JSX code:', error, strJSX);
    }

    /* NOTE: this will go into a callback once babel-standalone is updated to @babel/standalone. */
    if( tBabel!==null ) {
      const tCode = this.strJsxHeaderCode + tBabel.code + "\nreturn Interaction;\n";
      try {
        const tFn = new Function('atComponents', tCode);

        try {
          tElement = tFn(this.atComponents);
        } catch(error) {
          console.error('Failed to create the interaction element:', error, tCode);
        }
      } catch(error) {
        console.error('Failed to parse the received code:', error, tCode);
      }
    }

    return tElement;
  }


  onMessage_State(tJson) {
    // TODO: Validate the incoming JSON.

    // Track state changes in this variable. Only set a new state if one or more elements differ.
    let fStateChanged = false;
    // Track changes of the interaction data.
    let fInteractionDataChanged = false;

    // Create a new state with default values.
    let tStateNew = {};

    let strTitle = null;
    if('title' in tJson) {
      strTitle = tJson.title;
    }
    if( strTitle!==this.state.tTest_Title ) {
      tStateNew.tTest_Title = strTitle;
      fStateChanged = true;
    }

    let strSubtitle = null;
    if('subtitle' in tJson) {
      strSubtitle = tJson.subtitle;
    }
    if( strSubtitle!==this.state.tTest_Subtitle ) {
      tStateNew.tTest_Subtitle = strSubtitle;
      fStateChanged = true;
    }

    let fHasSerial = false;
    if('hasSerial' in tJson) {
      fHasSerial = tJson.hasSerial;
    }
    if( fHasSerial!==this.state.tTest_fHasSerial ) {
      tStateNew.tTest_fHasSerial = fHasSerial;
      fStateChanged = true;
    }

    let uiCurrentSerial = null;
    if('currentSerial' in tJson) {
      uiCurrentSerial = tJson.currentSerial;
    }
    if( uiCurrentSerial!==this.state.tRunningTest_uiCurrentSerial ) {
      tStateNew.tRunningTest_uiCurrentSerial = uiCurrentSerial;
      fStateChanged = true;
    }

    let uiRunningTest = null;
    if('runningTest' in tJson) {
      uiRunningTest = tJson.runningTest;
    }
    if( uiRunningTest!==this.state.tRunningTest_uiRunningTest ) {
      tStateNew.tRunningTest_uiRunningTest = uiRunningTest;
      fStateChanged = true;
    }

    // Compare all test names and states.
    let astrTestNames = [];
    let atTestStati = [];
    if('tests' in tJson) {
      tJson.tests.forEach(function(tAttr, uiIndex) {
        astrTestNames.push(tAttr.name);
        atTestStati.push(tAttr.state);
      }, this);
      const fIsEqual = (
        this.equalsFlatArrays(astrTestNames, this.state.astrTestNames) &&
        this.equalsFlatArrays(atTestStati, this.state.atTestStati)
      );
      if( !fIsEqual ) {
        tStateNew.tTest_astrTestNames = astrTestNames;
        tStateNew.tTest_atTestStati = atTestStati;
        fStateChanged = true;
      }
    }

    let atDocs = []
    if('docs' in tJson) {
      tJson.docs.forEach(function(tAttr, uiIndex) {
        if(('name' in tAttr) && ('url' in tAttr)) {
          atDocs.push({name: tAttr.name, url: tAttr.url});
        }
      }, this);
    }
    const fIsEqual = (
      (atDocs.length == this.state.tTest_atDocuments) &&
      atDocs.every((tAttr, uiIndex) => (
        ('name' in tAttr) &&
        ('url' in tAttr) &&
        ('name' in this.state.tTest_atDocuments[uiIndex]) &&
        ('url' in this.state.tTest_atDocuments[uiIndex]) &&
        (tAttr.name === this.state.tTest_atDocuments[uiIndex].name ) &&
        (tAttr.url === this.state.tTest_atDocuments[uiIndex].url )
      ))
    );
    if( !fIsEqual ) {
      tStateNew.tTest_atDocuments = atDocs;
      fStateChanged = true;
    }

    // Check for an interaction. If the JSON message does not contain one, clear it.
    let strInteraction = null;
    if('interaction' in tJson) {
      strInteraction = tJson.interaction;
    }
    if( strInteraction!==this.state.tUI_strInteraction ) {
      let tInteraction = null;
      if( strInteraction!==null && strInteraction!=='' ) {
        tInteraction = this.createInteraction(strInteraction);
      }
      tStateNew.tUI_strInteraction = strInteraction;
      tStateNew.tUI_tInteraction = tInteraction;
      fStateChanged = true;

      // Clear old interaction data.
      this.m_tUI_strInteractionData = null;
      // Clear any old peristance states.
      this.m_tInitialPersistenceState = null;
    }

    let strInteractionData = null;
    if('interaction_data' in tJson) {
      strInteractionData = tJson.interaction_data;
    }
    // Was the interaction created in this call?
    if('tUI_strInteraction' in tStateNew) {
      // The interaction did not mount yet.
      this.m_tUI_strInteractionData = strInteractionData;
      fInteractionDataChanged = true;

    // The interaction exists already. Only update it if there are changes.
    } else if(strInteractionData!==this.m_tUI_strInteractionData) {
      this.m_tUI_strInteractionData = strInteractionData;
      fInteractionDataChanged = true;
    }


    if('persistence' in tJson) {
      const tPeristence = tJson.persistence;
      if('app' in tPeristence) {
        const tPeristenceApp = tPeristence.app;
        if('enricoMode' in tPeristenceApp) {
          const fEnricoMode = tPeristenceApp.enricoMode;
          if( fEnricoMode!==this.state.enricoMode ) {
            tStateNew.enricoMode = fEnricoMode;
            fStateChanged = true;
          }
        }
      }

      if('interaction' in tPeristence) {
        this.m_tInitialPersistenceState = tPeristence.interaction;
        fStateChanged = true;
      }
    }


    // Update the state if something changed.
    if( fStateChanged ) {
      // Did the interaction data change also?
      if( fInteractionDataChanged ) {
        // The state and the interaction data changed at once.
        // First apply the new state, then update the interaction data.
        this.setState(tStateNew, this.callbackSetState_UpdateInteractionData);
      } else {
        // Only the state changed.
        this.setState(tStateNew);
      }
    } else if( fInteractionDataChanged ) {
      // Only the interaction data changed.
      this.callbackSetState_UpdateInteractionData();
    }
  }


  callbackSetState_UpdateInteractionData = () => {
    /* Does an interaction exist? */
    let tElement = this.tTesterInteraction.current;
    if( tElement!==null ) {
      if( typeof(tElement.onInteractionData)=="function" ) {
        tElement.onInteractionData(this.m_tUI_strInteractionData);
      }
    }
  }


  onMessage_Log(tJson) {
    const uiLogFilterLevel = this.uiLogFilterLevel;

    /* Loop over all new lines. */
    tJson.lines.forEach(function(strLine, uiIndex) {
      const astrLine = strLine.match(this.regexpLogLine);
      if( astrLine==null ) {
        console.error('Ignoring invalid log entry:' + strLine);
      } else {
        const uiLevel = parseInt(astrLine[1]);
        if( uiLevel<=uiLogFilterLevel ) {
          const strNewLine = strLine.substring(astrLine[0].length);
          this.message(uiLevel, strNewLine);
        }
      }
    }, this);
  }


  onMessage_Heartbeat() {
    // Add the heartbeat to the list.
    // The timestamp is in milliseconds. Convert it to seconds.
    const ulTimestampS = Date.now() / 1000;
    this.atHeartbeats.push(ulTimestampS);

    this.weedOutOldHeartbeats();
  }


  callbackSetState_SendStateToServer = () => {
    const tSocket = this.tSocket;
    if( tSocket!==null ) {
      const strJson = JSON.stringify({
        id: 'Persist',
        data: {
          enricoMode: this.state.enricoMode
        }
      });
      tSocket.send(strJson);
    }
  }


  // Set the persistence state.
  // If "tState" is not set or "null", get the default state
  // of the interaction.
  setPersietenceState = (tState=null) => {
    if( tState===null ) {
      /* Get the interaction state if it exists. */
      const tElement = this.tTesterInteraction.current;
      if( tElement!==null ) {
        tState = tElement.state;
      }
    }
    if( tState!==null ) {
      const strJson = JSON.stringify({
        id: 'Persist',
        data: {
          interaction: tState
        }
      });
      const tSocket = this.tSocket;
      if( tSocket!==null ) {
        tSocket.send(strJson);
      }
    }
  }


  getPersistentState = () => {
    // Return the initial persistence state.
    return this.m_tInitialPersistenceState;
  }


  sendInteractionMessage = (atObject) => {
    /* TODO: The argument must be an object. */

    /* Add the ID to the object. */
    atObject.id = 'RspInteraction';

    const tSocket = this.tSocket;
    if( tSocket!==null ) {
      const strJson = JSON.stringify(atObject);
      tSocket.send(strJson);
    }
  };


  getCurrentSerial = () => {
    return this.state.tRunningTest_uiCurrentSerial;
  };


  getRunningTest = () => {
    return this.state.tRunningTest_uiRunningTest;
  };

  getTestNames = () => {
    return this.state.tTest_astrTestNames;
  };

  getTestStati = () => {
    // Return a copy of the states.
    return this.state.tTest_atTestStati.slice();
  };

  setLocalTestState = (uiTestStep, strState) => {
    /* Is the test step valid? */
    if(uiTestStep>=this.state.tTest_astrTestNames.lengt) {
      /* No -> log an error. */
      this.log(LOG_ERROR, 'The function fnSetLocalTestState was called with an invalid index: ' + uiTestStep.toString())
    } else {
      /* Update the local state. This triggers an UI update. */
      let atNewTestStati = this.state.tTest_atTestStati.slice();
      atNewTestStati[uiTestStep] = strState;
      this.setState({
        tTest_atTestStati: atNewTestStati
      });
    }
  };

  getEnricoMode = () => {
    return this.state.enricoMode;
  }


  componentDidMount() {
    /* Create the websocket if it does not exist yet. */
    if( this.state.tState===TesterAppState_Idle )
    {
      this.doConnect();
    }

    // Create a timer for the connection state.
    if( this.tHeartbeatTimer==null ) {
      this.tHeartbeatTimer = setInterval(this.onHeartbeatTimer, 1000);
    }
  }

  componentWillUnmount() {
    // Stop the timer for the connection state.
    if( this.tHeartbeatTimer!=null ) {
      clearInterval(this.tHeartbeatTimer);
      this.tHeartbeatTimer = null;
    }

    /* Close the websocket. */
    if( this.tSocket!==null )
    {
      this.tSocket.close();
    }
  }

  weedOutOldHeartbeats() {
    // The timestamp is in milliseconds. Convert it to seconds.
    const ulTimestampS = Date.now() / 1000;
    // Keep only the last 10 seconds.
    const ulBorder = ulTimestampS - 10;
    const atFiltered = this.atHeartbeats.filter(ulTimestamp => ulTimestamp > ulBorder);
    this.atHeartbeats = atFiltered;
  }


  onHeartbeatTimer = () => {
    // Remove old heartbeats.
    this.weedOutOldHeartbeats();

    // Count the remaining heartbeats if the connection is still alive.
    if( this.state.tState==TesterAppState_Connected ) {
      const sizHeartbeats = this.atHeartbeats.length;
      let tNewState = null;
      switch(sizHeartbeats) {
        case 0:
          tNewState = ConnectionState_Ok0;
          break;
        case 1:
          tNewState = ConnectionState_Ok1;
          break;
        case 2:
          tNewState = ConnectionState_Ok2;
          break;
        case 3:
          tNewState = ConnectionState_Ok3;
          break;
        default:
          tNewState = ConnectionState_Ok4;
          break;
      }

      // Only update a changed state to prevent needless redraws.
      if( tNewState!=this.state.tConnectionState) {
        this.setState({
          tConnectionState: tNewState
        });
      }
    }
  }


  handleOpenAppMenu = () => {
    this.setState({
      fMenuIsOpen: true
    });
  }

  handleCloseAppMenu = () => {
    this.setState({
      fMenuIsOpen: false
    });
  }

  doConnect = () => {
    if( this.m_strServerURL===null ) {
      const tMsg = (
        <div>
          <Typography align="center" variant="h2" gutterBottom>Failed to locate the server!</Typography>
        </div>
      );
      this.setState({
        tState: TesterAppState_FatalError,
        tErrorMessage: tMsg
      });
    } else {
      var _socket = new WebSocket(this.m_strServerURL, this.m_strServerProtocol);
      if( _socket===null ) {
        const tMsg = (
          <div>
            <Typography align="center" variant="h2" gutterBottom>Failed to create the websocket!</Typography>
          </div>
        );
        this.setState({
          tState: TesterAppState_FatalError,
          tErrorMessage: tMsg
        });
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

  doDisconnect = () => {
    if( this.tSocket!==null )
    {
      this.tSocket.close();
    }
  }


  doCancelTest = () => {
    console.log('Cancel test');

    const tSocket = this.tSocket;
    if( tSocket!==null ) {
      const strJson = JSON.stringify({id: 'Cancel'});
      tSocket.send(strJson);
    }
  }


  doToggleDocuments = (tEvent) => {
    /* Do not pass the event to the other components or the menu will close. */
    tEvent.stopPropagation();

    this.setState({
      fMenuDocumentsOpen: !this.state.fMenuDocumentsOpen
    });
  }


  handleToggleEnricoMode = () => {
    const bEnricoMode = !this.state.enricoMode;
    if( bEnricoMode ) {
      this.log(LOG_WARNING, 'Oha, Enrico Mode ist an. Nu aber nicht zu dolle machen. ;-)');
    } else {
      this.log(LOG_INFO, 'Enrico Mode ist aus.');
    }

    // Update the state and send it to the server.
    this.setState(
      {
        enricoMode: bEnricoMode
      },
      this.callbackSetState_SendStateToServer
    );
  }


  doShowDocument = (uiIndex) => {
    if(uiIndex in this.state.tTest_atDocuments) {
      const tAttr = this.state.tTest_atDocuments[uiIndex];
      if('url' in tAttr) {
        const strUrl = tAttr.url;
        console.log('Open document at URL:', strUrl);
        window.open(strUrl, '_blank');
      }
    }
  }


  doToggleLog = () => {
    const tTerminalDiv = document.getElementById('terminal_log');
    let strVisibility = tTerminalDiv.style.visibility;
    if( strVisibility=="visible" ) {
      strVisibility = "hidden";
    } else {
      strVisibility = "visible";
    }
    tTerminalDiv.style.visibility = strVisibility;
  }


  render() {
    let tTabContentsInteraction = null;
    if( this.state.tState===TesterAppState_Idle ) {
      tTabContentsInteraction = (
        <div>
          <Typography align="center" variant="h2" gutterBottom>Welcome to the TesterUI.</Typography>
          <Typography align="center" variant="subtitle1">Please wait until the application is initialized.</Typography>
        </div>
      );
    } else if( this.state.tState===TesterAppState_Connecting ) {
      tTabContentsInteraction = (
        <div>
          <Typography align="center" variant="h2" gutterBottom>Connecting...</Typography>
          <CircularProgress variant="indeterminate" />
        </div>
      );
    } else if( this.state.tState===TesterAppState_Connected ) {
      const tElement = this.state.tUI_tInteraction;
      if( tElement===null ) {
        tTabContentsInteraction = (
          <Typography align="center" variant="h4" gutterBottom>No interaction...</Typography>
        );
      } else {
        try {
          tTabContentsInteraction = React.createElement(tElement, {ref: this.tTesterInteraction});
        } catch(error) {
          console.error('Failed to instanciate the interaction element:', error);
          tTabContentsInteraction = (
            <Typography align="center" color="error" variant="h4" gutterBottom>Failed to create the interaction element.</Typography>
          );
        }
      }
    } else if( this.state.tState===TesterAppState_ConnectionClosed ) {
      tTabContentsInteraction = (
        <Typography align="center" variant="h2" gutterBottom>The connection was closed.</Typography>
      );
    } else if( this.state.tState===TesterAppState_FatalError || this.state.tState===TesterAppState_SoftError ) {
      tTabContentsInteraction = this.state.tErrorMessage;
    } else {
      tTabContentsInteraction = (
        <div>
          <Typography align="center" variant="h2" gutterBottom>Invalid state!</Typography>
          <Typography align="center" variant="subtitle1">{this.state.tState}</Typography>
        </div>
      );
    }

    /* Create the document items for the menu. */
    let atDocumentLinks = [];
    this.state.tTest_atDocuments.forEach(function(tAttr, uiIndex) {
      if(('name' in tAttr) && ('url' in tAttr)) {
        atDocumentLinks.push(
          <ListItemButton key={`Document_${uiIndex}`} onClick={() => this.doShowDocument(uiIndex)}>
            <ListItemText inset primary={tAttr.name}/>
          </ListItemButton>
        );
      }
    }, this);
    if( atDocumentLinks.length==0 ) {
      atDocumentLinks.push(
        <ListItem key="Document_0">
          <ListItemText inset primary="no documents"/>
        </ListItem>
      );
    }

    /* Create the application menu. */
    let tAppMenu = (
      <List>
        <ListItemButton key='Cancel test' onClick={this.doCancelTest}>
          <ListItemIcon><CancelIcon/></ListItemIcon>
          <ListItemText primary='Cancel test'/>
        </ListItemButton>
        <Divider/>
        <ListItemButton key='Connect' disabled={this.state.tState===TesterAppState_Connected || this.state.tState===TesterAppState_FatalError} onClick={this.doConnect}>
          <ListItemIcon><PowerIcon/></ListItemIcon>
          <ListItemText primary='Connect'/>
        </ListItemButton>
        <ListItemButton key='Disconnect' disabled={this.state.tState!==TesterAppState_Connected} onClick={this.doDisconnect}>
          <ListItemIcon><PowerOffIcon/></ListItemIcon>
          <ListItemText primary='Disconnect'/>
        </ListItemButton>
        <Divider/>
        <ListItemButton key='Documents' onClick={this.doToggleDocuments}>
          <ListItemIcon><DescriptionIcon/></ListItemIcon>
          <ListItemText primary='Documents'/>
          {this.state.fMenuDocumentsOpen ? <ExpandLess /> : <ExpandMore />}
        </ListItemButton>
        <Collapse in={this.state.fMenuDocumentsOpen} timeout="auto" unmountOnExit>
          {atDocumentLinks}
        </Collapse>
        <Divider/>
        <ListItemButton key='Toggle Log' onClick={this.doToggleLog}>
          <ListItemIcon><DescriptionIcon/></ListItemIcon>
          <ListItemText primary='Toggle Log'/>
        </ListItemButton>
        <ListItem>
          <ListItemIcon><BuildCircleIcon/></ListItemIcon>
          <ListItemText id='list-item-enrico-mode' primary='Enrico mode'/>
          <Switch
            edge="end"
            onChange={this.handleToggleEnricoMode}
            checked={this.state.enricoMode}
            inputProps={{
              'aria-labelledby': 'list-item-enrico-mode',
            }}
          />
        </ListItem>
      </List>
    );

    let tConnectionIcon = null;
    if( this.state.tConnectionState==ConnectionState_Ok0 ) {
      tConnectionIcon = <SignalWifi0BarIcon />;
    } else if( this.state.tConnectionState==ConnectionState_Ok1 ) {
      tConnectionIcon = <SignalWifi1BarIcon />;
    } else if( this.state.tConnectionState==ConnectionState_Ok2 ) {
      tConnectionIcon = <SignalWifi2BarIcon />;
    } else if( this.state.tConnectionState==ConnectionState_Ok3 ) {
      tConnectionIcon = <SignalWifi3BarIcon />;
    } else if( this.state.tConnectionState==ConnectionState_Ok4 ) {
      tConnectionIcon = <SignalWifi4BarIcon />;
    } else {
      tConnectionIcon = <SignalWifiConnectedNoInternet4Icon color="error" />;
    }

    return (
      <ThemeProvider theme={this.tTheme}>
        <CssBaseline>
          <div id='TesterApp'>
            <div id='TesterHeader'>
              <div id='TesterUIHoverButtons'>
                <Button variant="contained" color="warning" aria-label="Cancel test" onClick={this.doCancelTest}>
                  <CancelIcon/>
                  Cancel test
                </Button>
                <div style={{display: 'inline', margin: '1em'}}>
                  {tConnectionIcon}
                </div>
                <IconButton aria-label="Menu" aria-owns={this.state.fMenuIsOpen ? 'TesterUIAppMenu' : undefined} aria-haspopup="true" onClick={this.handleOpenAppMenu}>
                  <MenuIcon/>
                </IconButton>
              </div>
              <Drawer anchor="right" id='TesterUIAppMenu' open={this.state.fMenuIsOpen} onClose={this.handleCloseAppMenu}>
                <div tabIndex={0} role="button" onClick={this.handleCloseAppMenu} onKeyDown={this.handleCloseAppMenu}>
                  {tAppMenu}
                </div>
              </Drawer>
              <TesterUIHeader strTitle={this.state.tTest_Title} strSubtitle={this.state.tTest_Subtitle} fHasSerial={this.state.tTest_fHasSerial} uiCurrentSerial={this.state.tRunningTest_uiCurrentSerial} />
              <TesterUIStepMap astrTestNames={this.state.tTest_astrTestNames} atTestStati={this.state.tTest_atTestStati} fHasSerial={this.state.tTest_fHasSerial} uiRunningTest={this.state.tRunningTest_uiRunningTest} strIconSize={this.state.tUI_CowIconSize} theme={this.tTheme} />
            </div>
            <div id='TesterTabContents'>
              {tTabContentsInteraction}
            </div>
          </div>
        </CssBaseline>
      </ThemeProvider>
    );
  }
}


function initializeLogOverlay() {
  /* This is the solarized theme for XTerm from here: https://github.com/maniat1k/Solarizedxterm/blob/master/.Xdefaults */
  const tTheme = {
    background:    '#222222',
    foreground:    '#808080',
    cursor:        '#808080',
    cursorAccent:  '#222222',
    selection:     '#FFFFFF4D',
    black:         '#222222',
    brightBlack:   '#454545',
    red:           '#9E5641',
    brightRed:     '#CC896D',
    green:         '#6C7E55',
    brightGreen:   '#C4DF90',
    yellow:        '#CAAF2B',
    brightYellow:  '#FFE080',
    blue:          '#7FB8D8',
    brightBlue:    '#B8DDEA',
    magenta:       '#956D9D',
    brightMagenta: '#C18FCB',
    cyan:          '#4c8ea1',
    brightCyan:    '#6bc1d0',
    white:         '#808080',
    brightWhite:   '#cdcdcd'
  };

  /* Create a new terminal.
   * Options:
   *   convert EOL so that a "\n" moves to the start of the next line.
   *   disable STDIN as it is not needed.
   *   scrollback lines sets the number of lines available when scrolling up.
   *   theme is the color theme.
   */
  var tTerm = new Terminal({
    convertEol: true,
    disableStdin: true,
    scrollback: 5000,
    theme: tTheme
  });

  const tFitAddon = new FitAddon();
  tTerm.loadAddon(tFitAddon);

  var tTermDiv = document.getElementById('terminal_log');
  tTerm.open(tTermDiv);
  tFitAddon.fit();

  TesterLog_terminal = tTerm;
  TesterLog_terminal_fit = tFitAddon;

  /* Show a welcome message with all colors. */
  var strBuffer = 'Welcome to Muhkuh WebUI V' + muhkuh_package_version + ' ' + muhkuh_package_vcsversion + ' .\n' +
                  '\n' +
                  'Colors:\n';
  for(let uiColor=40; uiColor<50; ++uiColor) {
    strBuffer += '  \x1B[' + uiColor.toString() + 'm  \x1B[0m';
  }
  strBuffer += '\n';
  for(let uiColor=100; uiColor<110; ++uiColor) {
    strBuffer += '  \x1B[' + uiColor.toString() + 'm  \x1B[0m';
  }
  strBuffer += '\n\n';
  tTerm.write(strBuffer);

  /* Add a simple resize handler for the terminal. */
  function handleTerminalResize() {
    TesterLog_terminal_fit.fit();
  }
  window.addEventListener('resize', handleTerminalResize);
}

initializeLogOverlay();

const container = document.getElementById('index');
const root = createRoot(container);
root.render(<TesterApp />);
