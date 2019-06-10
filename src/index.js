import React from "react";
import ReactDOM from "react-dom";

import './style.scss';
import 'typeface-roboto';
import 'typeface-roboto-mono';

import { transform } from 'babel-standalone';
import { createMuiTheme } from '@material-ui/core/styles';
import Button from '@material-ui/core/Button';
import Checkbox from '@material-ui/core/Checkbox';
import CircularProgress from '@material-ui/core/CircularProgress';
import CssBaseline from '@material-ui/core/CssBaseline';
import Divider from '@material-ui/core/Divider';
import Drawer from '@material-ui/core/Drawer';
import ExpansionPanel from '@material-ui/core/ExpansionPanel';
import ExpansionPanelSummary from '@material-ui/core/ExpansionPanelSummary';
import ExpansionPanelDetails from '@material-ui/core/ExpansionPanelDetails';
import FilledInput from '@material-ui/core/FilledInput';
import FormControl from '@material-ui/core/FormControl';
import FormHelperText from '@material-ui/core/FormHelperText';
import IconButton from '@material-ui/core/IconButton';
import Input from '@material-ui/core/Input';
import InputLabel from '@material-ui/core/InputLabel';
import List from '@material-ui/core/List';
import ListItem from '@material-ui/core/ListItem';
import ListItemIcon from '@material-ui/core/ListItemIcon';
import ListItemText from '@material-ui/core/ListItemText';
import MenuItem from '@material-ui/core/MenuItem';
import MuiThemeProvider from '@material-ui/core/styles/MuiThemeProvider';
import OutlinedInput from '@material-ui/core/OutlinedInput';
import Paper from '@material-ui/core/Paper';
import Select from '@material-ui/core/Select';
import SvgIcon from '@material-ui/core/SvgIcon';
import Tabs from '@material-ui/core/Tabs';
import Tab from '@material-ui/core/Tab';
import TextField from '@material-ui/core/TextField';
import Typography from '@material-ui/core/Typography';

import CancelIcon from '@material-ui/icons/Cancel';
import MenuIcon from '@material-ui/icons/Menu';
import PowerIcon from '@material-ui/icons/Power';
import PowerOffIcon from '@material-ui/icons/PowerOff';

import TesterUIHeader from './testerui_header';
import TesterUILog from './testerui_log';
import TesterUISummary from './testerui_summary';
import TesterUITheme from './testerui_theme';


const TesterAppState_Idle = 0;
const TesterAppState_Connecting = 1;
const TesterAppState_Connected = 2;
const TesterAppState_ConnectionClosed = 3;
const TesterAppState_FatalError = 4;
const TesterAppState_SoftError = 5;

const TesterAppTab_Interaction = 0;
const TesterAppTab_TestLog = 1;
const TesterAppTab_SystemLog = 2;


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

    this.state = {
      tState: _tState,
      tErrorMessage: _tErrorMessage,
      uiActiveTab: TesterAppTab_Interaction,
      fMenuIsOpen: false,

      strServerURL: _strServerURL,
      strServerProtocol: 'echo',

      tTest_Title: null,
      tTest_Subtitle: null,
      tTest_fHasSerial: false,
      tTest_uiFirstSerial: 0,
      tTest_uiLastSerial: 0,
      tTest_astrTestNames: [],
      tTest_atTestStati: [],

      tRunningTest_uiCurrentSerial: null,
      tRunningTest_uiRunningTest: null,

      tUI_CowIconSize: '3em',
      tUI_tInteraction: null
    };

    /* All log lines combined in one string. */
    this.uiLogFilterLevel = 8;
    this.astrLevelLogLines = [];
    this.strLogLines = '';

    /* No socket created yet. */
    this.tSocket = null;

    /* Provide all necessary components to parse JSX.
     * TODO: But what is necessary?
     */
    const atComponents = {
      'fnSend': this.sendInteractionMessage,
      'fnGetTestNames': this.getTestNames,
      'fnGetTestStati': this.getTestStati,
      'fnSetTestState': this.setTestState,
      'fnSetAllTestStati': this.setAllTestStati,
      'React': React,
      'ReactDOM': ReactDOM,
      'Button': Button,
      'Checkbox': Checkbox,
      'CircularProgress': CircularProgress,
      'ExpansionPanel': ExpansionPanel,
      'ExpansionPanelSummary': ExpansionPanelSummary,
      'ExpansionPanelDetails': ExpansionPanelDetails,
      'FilledInput': FilledInput,
      'FormControl': FormControl,
      'FormHelperText': FormHelperText,
      'IconButton': IconButton,
      'Input': Input,
      'InputLabel': InputLabel,
      'List': List,
      'ListItem': ListItem,
      'ListItemIcon': ListItemIcon,
      'ListItemText': ListItemText,
      'MenuItem': MenuItem,
      'OutlinedInput': OutlinedInput,
      'Paper': Paper,
      'Select': Select,
      'SvgIcon': SvgIcon,
      'Tabs': Tabs,
      'Tab': Tab,
      'TextField': TextField,
      'Typography': Typography
    };
    this.atComponents = atComponents;
    /* Generate the code to assign the components. */
    let astrCode = [];
    for(const strName in atComponents) {
      astrCode.push('const ' + strName + ' = atComponents.' + strName + ';');
    }
    this.strJsxHeaderCode = astrCode.join('\n') + '\n';

    /* This is a reference to the scroll container. */
    this.tTesterTab = React.createRef();

    /* This is a reference to the log. */
    this.tTesterLog = React.createRef();

    /* This is the scroll position for all tester tabs. */
    this.auiScrollPosition = [0, 0, 0];

    const atResultNameToId = new Map([
      ['ok', 0],
      ['error', 1],
      ['idle', 2],
      ['disabled', 3]
    ]);
    this.atResultNameToId = atResultNameToId;
    /* Generate a reverse mapping. */
    let atResultIdToName = new Map();
    atResultNameToId.forEach(function(uiIndex, strName) {
      const uiId = atResultNameToId.get(strName);
      atResultIdToName.set(uiId, strName);
    }, this);
    this.atResultIdToName = atResultIdToName;

    /* TODO: remove this. */
    this.demo_counter = 0;
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

      case 'SetInteraction':
        this.onMessage_SetInteraction(tJson);
        break;

      case 'Log':
        this.onMessage_Log(tJson);
        break;

      default:
        console.error('Received unknown message id:', strId);
      }
    } catch(error) {
      console.error("Received malformed JSON:", error, tEvent.data);
    }
  }

  onMessage_SetTitle(tJson) {
    this.setState({
      tTest_Title: tJson.title,
      tTest_Subtitle: tJson.subtitle,
      tTest_fHasSerial: tJson.hasSerial,
      tTest_uiFirstSerial: tJson.firstSerial,
      tTest_uiLastSerial: tJson.lastSerial
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

  onMessage_SetInteraction(tJson) {
    /* Translate the received code with babel. */
    const strJSX = tJson.jsx;
    let tBabel = null;
    try {
      tBabel = transform(
        strJSX,
        {
          filename: 'dynamic_loaded.jsx',
          presets: ['es2015', 'stage-2' , 'react']
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
            uiActiveTab: TesterAppTab_Interaction,
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

  onMessage_Log(tJson) {
    const uiLogFilterLevel = this.uiLogFilterLevel;
    let astrLevelLogLines = this.astrLevelLogLines;
    const tTesterLog = this.tTesterLog.current;

    /* Loop over all new lines. */
    tJson.lines.forEach(function(strLine, uiIndex) {
      /* Append the new line to the log. */
      astrLevelLogLines.push(strLine)

      let a = strLine.split(',', 2)
      let n = parseInt(a[0])
      if( n<=uiLogFilterLevel ) {
        const strNewLine = a[1];
        this.strLogLines += strNewLine;

        /* Append the new line to the display if it is visible. */
        if( tTesterLog!==null ) {
          tTesterLog.append(strNewLine);
        }
      }
    }, this);
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
      if( strState in this.atResultNameToId ) {
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
      if( strState in this.atResultNameToId ) {
        const uiState = this.atResultNameToId.get(strState);
        atStati[uiIndex] = uiState;
      }
    }, this);

    this.setState({
      tTest_atTestStati: atStati
    });
  };

  afterTabChange = () => {
    /* Set the new scroll position. */
    const tTesterTab = this.tTesterTab.current;
    if( tTesterTab!==null ) {
      const uiActiveTab = this.state.uiActiveTab;
      const uiNewPos = this.auiScrollPosition[uiActiveTab];
      tTesterTab.scrollTop = uiNewPos;
    }
  };

  handleTabChange = (tEvent, uiValue) => {
    /* Get the scroll position of the old tab. */
    const uiActiveTab = this.state.uiActiveTab;
    const tTesterTab = this.tTesterTab.current;
    if( tTesterTab!==null ) {
      const uiScrollTop = tTesterTab.scrollTop;
      this.auiScrollPosition[uiActiveTab] = uiScrollTop;
    }

    /* Change the tab. */
    this.setState({ uiActiveTab: uiValue }, this.afterTabChange);
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

  appendDemoLogLine() {
    /* Create a new demo line. */
    const strNewLines = 'Line ' + String(this.demo_counter) + '\n';
    this.demo_counter += 1;

    /* Append the new line to the log. */
    this.strLogLines += strNewLines;

    /* Append the new line to the display if it is visible. */
    const tTesterLog = this.tTesterLog.current;
    if( tTesterLog!==null ) {
      tTesterLog.append(strNewLines);
    }
  }

  handleCowClick = (uiIndex) => {
//    this.appendDemoLogLine();
    this.interval = setInterval(() => this.appendDemoLogLine(), 100);

    this.setState({
      tRunningTest_uiRunningTest: uiIndex
    });
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

    clearInterval(this.interval);

    this.setState({
      tRunningTest_uiRunningTest: null
    });
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
          tTabContentsInteraction = React.createElement(tElement);
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

    const tTabContentsLog = (
      <TesterUILog ref={this.tTesterLog} strLogLines={this.strLogLines}/>
    );

    const tTabContentsSystemLog = (
      <Typography align="center" variant="h2" gutterBottom>System log</Typography>
    );

    /* Create the application menu. */
    let tAppMenu = (
      <List>
        <ListItem button key='Cancel test' disabled={this.state.tRunningTest_uiRunningTest===null} onClick={this.doCancelTest}>
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
      </List>
    );

    const uiActiveTab = this.state.uiActiveTab;
    return (
      <MuiThemeProvider theme={TesterUITheme}>
        <CssBaseline>
          <div id='TesterApp'>
            <div id='TesterHeader'>
              <div id='TesterUIHoverButtons'>
                <Button variant="extendedFab" aria-label="Cancel test" disabled={this.state.tRunningTest_uiRunningTest===null} onClick={this.doCancelTest}>
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
              <TesterUIHeader strTitle={this.state.tTest_Title} strSubtitle={this.state.tTest_Subtitle} fHasSerial={this.state.tTest_fHasSerial} uiFirstSerial={this.state.tTest_uiFirstSerial} uiLastSerial={this.state.tTest_uiLastSerial} />
              <TesterUISummary astrTestNames={this.state.tTest_astrTestNames} atTestStati={this.state.tTest_atTestStati} fHasSerial={this.state.tTest_fHasSerial} uiCurrentSerial={this.state.tRunningTest_uiCurrentSerial} uiRunningTest={this.state.tRunningTest_uiRunningTest} strIconSize={this.state.tUI_CowIconSize} theme={TesterUITheme} handleCowClick={this.handleCowClick} />
              <div id='TesterTabs'>
                <Tabs value={uiActiveTab} onChange={this.handleTabChange}>
                  <Tab label="Interaction" />
                  <Tab label="Test Log" />
                  <Tab label="System Log" />
                </Tabs>
              </div>
            </div>
            <div id='TesterTabContents' ref={this.tTesterTab}>
              <div style={{display: ((uiActiveTab==TesterAppTab_Interaction) ? 'inline' : 'none')}}>
                {tTabContentsInteraction}
              </div>
              <div style={{display: ((uiActiveTab==TesterAppTab_TestLog) ? 'inline' : 'none')}}>
                {tTabContentsLog}
              </div>
              <div style={{display: ((uiActiveTab==TesterAppTab_SystemLog) ? 'inline' : 'none')}}>
                {tTabContentsSystemLog}
              </div>
            </div>
          </div>
        </CssBaseline>
      </MuiThemeProvider>
    );
  }
}


ReactDOM.render(<TesterApp />, document.getElementById("index"));
