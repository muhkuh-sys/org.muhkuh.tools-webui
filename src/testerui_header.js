import React from "react";
import ReactDOM from "react-dom";

import Typography from '@material-ui/core/Typography';

class TesterUIHeader extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      strTitle: 'NXHX 90-JTAG R3',
      strSubtitle: '7730.010',
      fHasSerial: true,
      uiFirstSerial: 20000,
      uiLastSerial: 20009
    };
  }

  render() {
    return (
      <div>
        <Typography variant="h4" gutterBottom>{this.state.strTitle}</Typography>
        <Typography variant="subtitle1" gutterBottom>{this.state.strSubtitle}</Typography>
        <Typography variant="body1" gutterBottom>First serial: {this.state.uiFirstSerial}, last serial: {this.state.uiLastSerial}</Typography>
      </div>
    );
  }
}

export default TesterUIHeader
