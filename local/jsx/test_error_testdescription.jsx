class Interaction extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    return (
      <div>
        <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
          <Typography variant="h2" gutterBottom>Unkonfigurierte Teststation.</Typography>
          <Typography variant="subtitle1" gutterBottom>Diese Teststation ist noch nicht fertig konfiguriert.</Typography>
        </div>
      </div>
    );
  }
}
