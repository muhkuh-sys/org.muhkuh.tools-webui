class Interaction extends React.Component {
  constructor(props) {
    super(props);
  }

  handleButtonStart = () => {
    const tMsg = {
      button: 'start'
    };
    fnSend(tMsg);
  };

  render() {
    return (
      <div>
        <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
          <Typography variant="h2" gutterBottom>Hier läuft noch nichts.</Typography>
          <Typography variant="subtitle1" gutterBottom>Aber wenn Du auf "Start" klickst, geht es los.</Typography>
        </div>

        <div style={{width: '100%', textAlign: 'center'}}>
          <Button color="primary" variant="contained" size="large" onClick={this.handleButtonStart}>
            <SvgIcon>
              <path d="M8 5v14l11-7z"/><path d="M0 0h24v24H0z" fill="none"/>
            </SvgIcon>
            Start
          </Button>
        </div>
      </div>
    );
  }
}
