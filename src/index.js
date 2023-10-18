import React from 'react';

import css from './style.css';
import 'typeface-roboto';
import 'typeface-roboto-mono';

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
import ListItemIcon from '@mui/material/ListItemIcon';
import ListItemText from '@mui/material/ListItemText';
import MenuItem from '@mui/material/MenuItem';
import OutlinedInput from '@mui/material/OutlinedInput';
import Paper from '@mui/material/Paper';
import Radio from '@mui/material/Radio';
import RadioGroup from '@mui/material/RadioGroup';
import Select from '@mui/material/Select';
import SvgIcon from '@mui/material/SvgIcon';
import Tabs from '@mui/material/Tabs';
import Tab from '@mui/material/Tab';
import TextField from '@mui/material/TextField';
import { TreeView } from '@mui/x-tree-view/TreeView';
import { TreeItem } from '@mui/x-tree-view/TreeItem';
import Typography from '@mui/material/Typography';

import Ajv from "ajv";
import ReactImageZoom from 'react-image-zoom';

import CancelIcon from '@mui/icons-material/Cancel';
import DescriptionIcon from '@mui/icons-material/Description';
import ExpandLess from '@mui/icons-material/ExpandLess';
import ExpandMore from '@mui/icons-material/ExpandMore';
import MenuIcon from '@mui/icons-material/Menu';
import PowerIcon from '@mui/icons-material/Power';
import PowerOffIcon from '@mui/icons-material/PowerOff';

import { Terminal } from "xterm";
import { FitAddon } from 'xterm-addon-fit';

import TesterUIHeader from './testerui_header';
import TesterUISummary from './testerui_summary';


const TesterAppState_Idle = 0;
const TesterAppState_Connecting = 1;
const TesterAppState_Connected = 2;
const TesterAppState_ConnectionClosed = 3;
const TesterAppState_FatalError = 4;
const TesterAppState_SoftError = 5;


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
      _strServerURL = g_CFG_strServerURL;
    }

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

      strServerURL: _strServerURL,
      strServerProtocol: 'muhkuh-tester',

      tTest_Title: null,
      tTest_Subtitle: null,
      tTest_fHasSerial: false,
      tTest_astrTestNames: [],
      tTest_atTestStati: [],
      tTest_atDocuments: [],

      tRunningTest_uiCurrentSerial: null,
      tRunningTest_uiRunningTest: null,

      tUI_CowIconSize: '5em',
      tUI_tInteraction: null
    };

    /* All log lines combined in one string. */
    this.uiLogFilterLevel = 8;

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
      'fnSetTestState': this.setTestState,
      'fnSetAllTestStati': this.setAllTestStati,
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
console.log(this.strJsxHeaderCode);

    /* This is a reference to the interaction element. */
    this.tTesterInteraction = React.createRef();

    /* This is the tester terminal. */
    this.tTesterLog_terminal = TesterLog_terminal;
    this.tTesterLog_terminal_fit = TesterLog_terminal_fit;

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

    const atResultNameToId = new Map([
      ['ok', 0],
      ['error', 1],
      ['idle', 2],
      ['disabled', 3],
      ['excluded', 4]
    ]);
    this.atResultNameToId = atResultNameToId;
    /* Generate a reverse mapping. */
    let atResultIdToName = new Map();
    atResultNameToId.forEach(function(uiIndex, strName) {
      const uiId = atResultNameToId.get(strName);
      atResultIdToName.set(uiId, strName);
    }, this);
    this.atResultIdToName = atResultIdToName;

    /* This is a regexp for matching log lines. */
    this.regexpLogLine = new RegExp('(\\d+),');

    registerPlugin('@babel/plugin-proposal-class-properties')
  }

  socketClosed(tEvent) {
    console.log("WebSocket is closed now.");
    if( this.state.tState==TesterAppState_Connected ) {
      this.setState({ tState: TesterAppState_ConnectionClosed });
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
    this.setState({ tState: TesterAppState_Connected });
  }

  socketMessage(tEvent) {
    console.debug("WebSocket message received:", tEvent.data);

    try {
      let tJson = JSON.parse(tEvent.data);
      let strId = tJson.id;
      switch(strId) {
      case 'SetTitle':
        this.onMessage_SetTitle(tJson);
        break;

      case 'SetTestNames':
        this.onMessage_setTestNames(tJson);
        break;

      case 'SetTestStati':
        this.onMessage_setTestStati(tJson);
        break;

      case 'SetInteraction':
        this.onMessage_SetInteraction(tJson);
        break;

      case 'SetInteractionData':
        this.onMessage_SetInteractionData(tJson);
        break;

      case 'Log':
        this.onMessage_Log(tJson);
        break;

      case 'SetCurrentSerial':
        this.onMessage_SetCurrentSerial(tJson)
        break;

      case 'SetRunningTest':
        this.onMessage_SetRunningTest(tJson)
        break;

      case 'SetTestState':
        this.onMessage_SetTestState(tJson)
        break;

      case 'SetDocs':
        this.onMessage_SetDocs(tJson)
        break;

      default:
        console.error('Received unknown message id:', strId);
      }
    } catch(error) {
      console.error("Received malformed JSON:", error, tEvent.data);
    }
  }

  onMessage_SetTitle(tJson) {
    let strTitle = null;
    if('title' in tJson) {
      strTitle = tJson.title;
    }

    let strSubtitle = null;
    if('subtitle' in tJson) {
      strSubtitle = tJson.subtitle;
    }

    let fHasSerial = false;
    if('hasSerial' in tJson) {
      fHasSerial = tJson.hasSerial;
    }

    this.setState({
      tTest_Title: strTitle,
      tTest_Subtitle: strSubtitle,
      tTest_fHasSerial: fHasSerial
    });
  }

  onMessage_setTestNames(tJson) {
    /* Check the JSON. The test names must be an array. */
    if('testNames' in tJson) {
      const astrNames = tJson.testNames;
      if( Array.isArray(astrNames)==true ) {
        /* Copy all names and set the state to "idle". */
        let astrTestNames = [];
        let atTestStati = [];
        const tDefaultState = 2;

        astrNames.forEach(function(strName, uiIndex) {
          astrTestNames.push(strName);
          atTestStati.push(tDefaultState);
        }, this);

        this.setState({
          tTest_astrTestNames: astrTestNames,
          tTest_atTestStati: atTestStati
        });
      }
    }
  }

  onMessage_setTestStati(tJson) {
    /* Check the JSON. The test stati must be an array. */
    if('testStati' in tJson) {
      const astrStati = tJson.testStati;
      if( Array.isArray(astrStati)==true ) {
        this.setAllTestStati(astrStati)
      }
    }
  }

  onMessage_SetInteraction(tJson) {
    /* Translate the received code with babel. */
    const strJSX = tJson.jsx;
    if( strJSX=='' ) {
      this.setState({
        tUI_tInteraction: null
      });
    } else {
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
        let tCode = this.strJsxHeaderCode + tBabel.code + "\nreturn Interaction;\n";
        try {
          const tFn = new Function('atComponents', tCode);

          try {
            const tElement = tFn(this.atComponents);
            this.setState({
              tUI_tInteraction: tElement
            });
          } catch(error) {
            console.error('Failed to create the interaction element:', error, tCode);
          }
        } catch(error) {
          console.error('Failed to parse the received code:', error, tCode);
        }
      }
    }
  }

  onMessage_SetInteractionData(tJson) {
    const strData = tJson.data;

    /* Does an interaction exist? */
    let tElement = this.tTesterInteraction.current;
    if( tElement!==null ) {
      if( typeof(tElement.onInteractionData)=="function" ) {
        tElement.onInteractionData(strData);
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

          /* Get the color for the log level. */
          let strColor = '';
          /* Only process valid log levels. */
          if( uiLevel>0 && uiLevel<10 ) {
            /* Set the new style if it differs from the last one. */
            if( this.uiLastLogLevel!=uiLevel ) {
              strColor = this.atLogLevelAnsiColors[uiLevel];
              this.uiLastLogLevel = uiLevel;
            }
          }

          /* Combine the color codes with the lines. */
          this.tTesterLog_terminal.write(strColor + strNewLine);
        }
      }
    }, this);
  }

  onMessage_SetCurrentSerial(tJson) {
    const uiCurrentSerial = tJson.currentSerial;
    this.setState({
      tRunningTest_uiCurrentSerial: uiCurrentSerial
    });
  }

  onMessage_SetRunningTest(tJson) {
    let uiRunningTest = null;
    if('runningTest' in tJson) {
      uiRunningTest = tJson.runningTest;
    }
    this.setState({
      tRunningTest_uiRunningTest: uiRunningTest
    });
  }

  onMessage_SetTestState(tJson) {
    const strTestState = tJson.testState;
    this.setTestState(strTestState);
  }

  onMessage_SetDocs(tJson) {
    if('docs' in tJson) {
      let atDocs = []
      tJson.docs.forEach(function(tAttr, uiIndex) {
        if(('name' in tAttr) && ('url' in tAttr)) {
          atDocs.push({name: tAttr.name, url: tAttr.url});
        }
      }, this);
      this.setState({
        tTest_atDocuments: atDocs
      });
    }
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
    let astrStati = [];
    this.state.tTest_atTestStati.forEach(function(uiState, uiIndex) {
      console.debug(uiState, uiIndex);
      astrStati[uiIndex] = this.atResultIdToName.get(uiState);
    }, this);
    return astrStati;
  };

  setTestState = (strState) => {
    /* Is a test running? */
    const uiRunningTest = this.state.tRunningTest_uiRunningTest;
    if( uiRunningTest!=null ) {
      /* Translate the state to an ID. */
      if( this.atResultNameToId.has(strState) ) {
        const uiState = this.atResultNameToId.get(strState);

        /* Clone the array. Do not modify the state contents directly. */
        let atStati = this.state.tTest_atTestStati.slice();

        /* Set the state. */
        atStati[uiRunningTest] = uiState;

        this.setState({
          tTest_atTestStati: atStati
        });
      }
    }
  };

  setAllTestStati = (astrStates) => {
    /* Clone the array. Do not modify the state contents directly. */
    let atStati = this.state.tTest_atTestStati.slice();

    /* Loop over all elements in the argument. */
    astrStates.forEach(function(strState, uiIndex) {
      /* Translate the state to an ID. */
      if( this.atResultNameToId.has(strState) ) {
        const uiState = this.atResultNameToId.get(strState);
        atStati[uiIndex] = uiState;
      }
    }, this);

    this.setState({
      tTest_atTestStati: atStati
    });
  };

  componentDidMount() {
    /* Create the websocket if it does not exist yet. */
    if( this.state.tState===TesterAppState_Idle )
    {
      this.doConnect();
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
//    this.interval = setInterval(() => this.appendDemoLogLine(), 100);
//
//    this.setState({
//      tRunningTest_uiRunningTest: uiIndex
//    });
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
    if( this.state.strServerURL===null ) {
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
      var _socket = new WebSocket(this.state.strServerURL, this.state.strServerProtocol);
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

    this.setState({
      tRunningTest_uiRunningTest: null
    });
  }


  doToggleDocuments = (tEvent) => {
    /* Do not pass the event to the other components or the menu will close. */
    tEvent.stopPropagation();

    this.setState({
      fMenuDocumentsOpen: !this.state.fMenuDocumentsOpen
    });
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
          <ListItem button key="Document_{uiIndex}" onClick={() => this.doShowDocument(uiIndex)}>
            <ListItemText inset primary={tAttr.name}/>
          </ListItem>
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
        <ListItem button key='Cancel test' onClick={this.doCancelTest}>
          <ListItemIcon><CancelIcon/></ListItemIcon>
          <ListItemText primary='Cancel test'/>
        </ListItem>
        <Divider/>
        <ListItem button key='Connect' disabled={this.state.tState===TesterAppState_Connected || this.state.tState===TesterAppState_FatalError} onClick={this.doConnect}>
          <ListItemIcon><PowerIcon/></ListItemIcon>
          <ListItemText primary='Connect'/>
        </ListItem>
        <ListItem button key='Disconnect' disabled={this.state.tState!==TesterAppState_Connected} onClick={this.doDisconnect}>
          <ListItemIcon><PowerOffIcon/></ListItemIcon>
          <ListItemText primary='Disconnect'/>
        </ListItem>
        <Divider/>
        <ListItem button key='Documents' onClick={this.doToggleDocuments}>
          <ListItemIcon><DescriptionIcon/></ListItemIcon>
          <ListItemText primary='Documents'/>
          {this.state.fMenuDocumentsOpen ? <ExpandLess /> : <ExpandMore />}
        </ListItem>
        <Collapse in={this.state.fMenuDocumentsOpen} timeout="auto" unmountOnExit>
          {atDocumentLinks}
        </Collapse>
        <Divider/>
        <ListItem button key='Toggle Log' onClick={this.doToggleLog}>
          <ListItemIcon><DescriptionIcon/></ListItemIcon>
          <ListItemText primary='Toggle Log'/>
        </ListItem>
      </List>
    );

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
              <TesterUISummary astrTestNames={this.state.tTest_astrTestNames} atTestStati={this.state.tTest_atTestStati} fHasSerial={this.state.tTest_fHasSerial} uiRunningTest={this.state.tRunningTest_uiRunningTest} strIconSize={this.state.tUI_CowIconSize} theme={this.tTheme} handleCowClick={this.handleCowClick} />
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
