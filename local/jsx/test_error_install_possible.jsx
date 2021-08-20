function MinusSquare(props) {
  return (
    <SvgIcon fontSize="inherit" style={{ width: 14, height: 14 }} {...props}>
      <path d="M22.047 22.074v0 0-20.147 0h-20.12v0 20.147 0h20.12zM22.047 24h-20.12q-.803 0-1.365-.562t-.562-1.365v-20.147q0-.776.562-1.351t1.365-.575h20.147q.776 0 1.351.575t.575 1.351v20.147q0 .803-.575 1.365t-1.378.562v0zM17.873 11.023h-11.826q-.375 0-.669.281t-.294.682v0q0 .401.294 .682t.669.281h11.826q.375 0 .669-.281t.294-.682v0q0-.401-.294-.682t-.669-.281z" />
    </SvgIcon>
  );
}

function PlusSquare(props) {
  return (
    <SvgIcon fontSize="inherit" style={{ width: 14, height: 14 }} {...props}>
      <path d="M22.047 22.074v0 0-20.147 0h-20.12v0 20.147 0h20.12zM22.047 24h-20.12q-.803 0-1.365-.562t-.562-1.365v-20.147q0-.776.562-1.351t1.365-.575h20.147q.776 0 1.351.575t.575 1.351v20.147q0 .803-.575 1.365t-1.378.562v0zM17.873 12.977h-4.923v4.896q0 .401-.281.682t-.682.281v0q-.375 0-.669-.281t-.294-.682v-4.896h-4.923q-.401 0-.682-.294t-.281-.669v0q0-.401.281-.682t.682-.281h4.923v-4.896q0-.401.294-.682t.669-.281v0q.401 0 .682.281t.281.682v4.896h4.923q.401 0 .682.281t.281.682v0q0 .375-.281.669t-.682.294z" />
    </SvgIcon>
  );
}

function TreeInstallIcon(props) {
  return (
    <SvgIcon className="treeinstallicon" fontSize="inherit" style={{ width: 18, height: 18 }} {...props}>
      <path d="M12 16.5l4-4h-3v-9h-2v9H8l4 4zm9-13h-6v1.99h6v14.03H3V5.49h6V3.5H3c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2v-14c0-1.1-.9-2-2-2z" />
    </SvgIcon>
  );
}


class Interaction extends React.Component {
  constructor(props) {
    super(props);

    this.strMessage = '@ERROR_MESSAGE@';
    this.tReader = null;
    this.ulSendPos = null;
    this.fCancelRequest = false;

    this.STATE_Started = 0;
    this.STATE_SelectSource = 1;
    this.STATE_SourceUpload_SelectFile = 2;
    this.STATE_SourceNexus_ReceiveList = 3;
    this.STATE_SourceNexus_SelectEntry = 4;
    this.STATE_SourceNexus_Downloading = 5;
    this.STATE_ConfirmInstall = 6;

    this.state = {
      tState: this.STATE_Started,
      strSource: 'nexus',
      ulFileSize: 0,
      fHaveFile: false,
      fIsUploading: false,
      fUploadFinished: false,
      ulProgress: 0,
      tPackageDetails: null,
      atArtifacts: null
    };
  }

  /* Taken from base64.js by Egor Nepomnyaschih from here:
   * https://gist.github.com/enepomnyaschih/72c423f727d395eeaa09697058238727
   *
   * MIT License
   *
   * Copyright (c) 2020 Egor Nepomnyaschih
   * Permission is hereby granted, free of charge, to any person obtaining a copy
   * of this software and associated documentation files (the "Software"), to deal
   * in the Software without restriction, including without limitation the rights
   * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   * copies of the Software, and to permit persons to whom the Software is
   * furnished to do so, subject to the following conditions:
   *
   * The above copyright notice and this permission notice shall be included in all
   * copies or substantial portions of the Software.
   *
   * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   * SOFTWARE.
   */
  bytesToBase64(bytes) {
    const base64abc = [
      "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
      "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
      "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
      "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
      "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "/"
    ];

    let result = '', i, l = bytes.length;
    for (i = 2; i < l; i += 3) {
      result += base64abc[bytes[i - 2] >> 2];
      result += base64abc[((bytes[i - 2] & 0x03) << 4) | (bytes[i - 1] >> 4)];
      result += base64abc[((bytes[i - 1] & 0x0F) << 2) | (bytes[i] >> 6)];
      result += base64abc[bytes[i] & 0x3F];
    }
    if (i === l + 1) { // 1 octet yet to write
      result += base64abc[bytes[i - 2] >> 2];
      result += base64abc[(bytes[i - 2] & 0x03) << 4];
      result += "==";
    }
    if (i === l) { // 2 octets yet to write
      result += base64abc[bytes[i - 2] >> 2];
      result += base64abc[((bytes[i - 2] & 0x03) << 4) | (bytes[i - 1] >> 4)];
      result += base64abc[(bytes[i - 1] & 0x0F) << 2];
      result += "=";
    }
    return result;
  };


  onFileChunk = (tChunk) => {
    if( this.fCancelRequest==true ) {
      this.setState({
        fIsUploading: false,
        fUploadFinished: false
      });
    } else {
      if( tChunk.done==true ) {
        console.log('Done.');

        const tMsg = {
          dl: 'done'
        };
        fnSend(tMsg);

        this.setState({
          fIsUploading: false,
          fUploadFinished: true
        });
      } else {
        const ulChunkSize = tChunk.value.length;
        console.log('read ' + ulChunkSize + ' bytes.');
        const ulSendPos = this.state.ulProgress + ulChunkSize;
        this.ulSendPos = ulSendPos;

        const strData = this.bytesToBase64(tChunk.value);
        const tMsg = {
          dl: 'data',
          data: strData,
          pos: ulSendPos
        };
        fnSend(tMsg);
      }
    }
  };


  makeTree(atArtifacts) {
    /* Build a tree with 4 levels.
     * On the first level are the first 2 chars of the artifact name.
     * Usually this will be the 2 most significant digits of the article
     * number. The next level shows the complete artifact name. The third
     * level shows the versions and the fourth level the classifier.
     */
    let atTree = [];
    atArtifacts.forEach(function(tArtifact) {
      /* Get the labels for the first 3 levels. */
      const strLevel1 = tArtifact.a.substring(0,2) + '...';
      const strLevel2 = tArtifact.a;
      const strLevel3 = tArtifact.v;

      tArtifact.l.forEach(function(tLink) {
        const strLevel4 = tLink.c;

        const tAttr = {
          g: tArtifact.g,
          a: tArtifact.a,
          v: tArtifact.v,
          c: tLink.c,
          e: tLink.e,
          r: tLink.r
        };

        let atLevel2 = null;
        let iL1Cnt=0;
        while( iL1Cnt<atTree.length ) {
          const tElem = atTree[iL1Cnt];
          const strL = tElem.l;
          if( strL==strLevel1 ) {
            atLevel2 = tElem.i;
            break;
          } else if( strL>=strLevel1 ) {
            break;
          } else {
            iL1Cnt++;
          }
        }
        if( atLevel2==null ) {
          atLevel2 = [];
          atTree.splice(iL1Cnt, 0, {
            l: strLevel1,
            i: atLevel2
          });
        }

        let atLevel3 = null;
        let iL2Cnt=0;
        while( iL2Cnt<atLevel2.length ) {
          const tElem = atLevel2[iL2Cnt];
          const strL = tElem.l;
          if( strL==strLevel2 ) {
            atLevel3 = tElem.i;
            break;
          } else if( strL>=strLevel2 ) {
            break;
          } else {
            iL2Cnt++;
          }
        }
        if( atLevel3==null ) {
          atLevel3 = [];
          atLevel2.splice(iL2Cnt, 0, {
            l: strLevel2,
            i: atLevel3
          });
        }

        let atLevel4 = null;
        let iL3Cnt=0;
        while( iL3Cnt<atLevel3.length ) {
          const tElem = atLevel3[iL3Cnt];
          const strL = tElem.l;
          if( strL==strLevel3 ) {
            atLevel4 = tElem.i;
            break;
          } else if( strL>=strLevel3 ) {
            break;
          } else {
            iL3Cnt++;
          }
        }
        if( atLevel4==null ) {
          atLevel4 = [];
          atLevel3.splice(iL3Cnt, 0, {
            l: strLevel3,
            i: atLevel4
          });
        }

        let iL4Cnt=0;
        while( iL4Cnt<atLevel4.length ) {
          const strL = atLevel4[iL3Cnt];
          if( strL>=strLevel4 ) {
            break;
          } else {
            iL4Cnt++;
          }
        }
        atLevel4.splice(iL4Cnt, 0, tAttr);
      });
    });

    console.log(atTree);
    return atTree;
  }


  onInteractionData = (strData) => {
    if( this.state.fIsUploading==true ) {
      if( this.fCancelRequest==true ) {
        this.setState({
          fIsUploading: false,
          fUploadFinished: false
        });
      } else {
        let tJson = null;
        try {
          tJson = JSON.parse(strData);
        } catch(error) {
          console.error("Received malformed JSON:", error, strData);
        }

        if( tJson!==null ) {
          const ulAck = tJson.ack;
          if( ulAck==this.ulSendPos ) {
            /* Move the progress bar. */
            this.setState({
              ulProgress: ulAck
            });

            /* Read the next chunk. */
            this.tReader.read().then(this.onFileChunk);
          } else {
            console.log("Got invalid ack.")
          }
        }
      }
    } else if( this.state.fUploadFinished==true ) {
      let tJson = null;
      try {
        tJson = JSON.parse(strData);
      } catch(error) {
        console.error("Received malformed JSON:", error, strData);
      }

      if( tJson!==null ) {
        /* Make a suggestion for the station name. */
        const strStationName = 'Muhkuh Teststation ' + tJson.archive.PACKAGE_NAME.replace(/_/g, ' ');
        this.setState({
          tState: this.STATE_ConfirmInstall,
          tPackageDetails: tJson,
          strStationName: strStationName
        });
      }
    } else if( this.state.tState==this.STATE_SourceNexus_ReceiveList ) {
      if( this.fCancelRequest==true ) {
        this.setState({
          tState: this.STATE_Started
        });
      } else {
        let tJson = null;
        try {
          tJson = JSON.parse(strData);
        } catch(error) {
          console.error("Received malformed JSON:", error, strData);
        }

        if( tJson!==null ) {
          if( 'progress' in tJson ) {
            this.setState({
              ulProgress: tJson.progress
            });
          } else if( 'artifacts' in tJson ) {
            this.setState({
              atArtifacts: this.makeTree(tJson.artifacts),
              tState: this.STATE_SourceNexus_SelectEntry
            })
          }
        }
      }
    } else if( this.state.tState==this.STATE_SourceNexus_Downloading ) {
      if( this.fCancelRequest==true ) {
        /* TODO... */
      } else {
        let tJson = null;
        try {
          tJson = JSON.parse(strData);
        } catch(error) {
          console.error("Received malformed JSON:", error, strData);
        }

        if( tJson!==null ) {
          console.log("progress:", tJson);
          if( 'progress' in tJson ) {
            this.setState({
              ulProgress: tJson.progress
            });
          } else if( 'archive' in tJson ) {
            /* Make a suggestion for the station name. */
            const strStationName = 'Muhkuh Teststation ' + tJson.archive.PACKAGE_NAME.replace(/_/g, ' ');
            this.setState({
              tState: this.STATE_ConfirmInstall,
              tPackageDetails: tJson,
              strStationName: strStationName
            });
          }
        }
      }
    }
  };


  handleInstall = () => {
    this.setState({
      tState: this.STATE_SelectSource
    });
  };


  handleSelectSourceRadio = (event) => {
    this.setState({
      strSource: event.target.value
    })
  };


  handleSelectSource = () => {
    let tState = this.STATE_SelectSource;
    const strSource = this.state.strSource;
    if( strSource=='nexus' ) {
      this.setState({
        tState: this.STATE_SourceNexus_ReceiveList,
      });
      fnSend({
        cmd: 'nexus_list'
      })
    } else if( strSource=='local' ) {
      this.setState({
        tState: this.STATE_SourceUpload_SelectFile
      });
    }
  };


  onNexusSelect(tAttr) {
    console.log(tAttr);

    this.setState({
      ulProgress: 0,
      tState: this.STATE_SourceNexus_Downloading,
    });
    fnSend({
      cmd: 'nexus_download',
      g: tAttr.g,
      a: tAttr.a,
      v: tAttr.v,
      c: tAttr.c,
      e: tAttr.e,
      r: tAttr.r
    })
  };


  handleFile = (event) => {
    const tFile = event.target.files[0];
    const tStream = tFile.stream();
    const tReader = tStream.getReader();

    this.tReader = tReader;
    this.setState({
      ulFileSize: tFile.size,
      fHaveFile: true,
      fIsUploading: false,
      fUploadFinished: false,
      ulProgress: 0
    });
  };


  handleFileSubmission = () => {
    console.log('Submission');

    const tMsg = {
      dl: 'start'
    };
    fnSend(tMsg);

    this.fCancelRequest = false;
    this.setState({
      fIsUploading: true,
      fUploadFinished: false,
      ulProgress: 0
    });

    /* Read the first chunk. */
    this.tReader.read().then(this.onFileChunk);
  };

  handleCancelButton = () => {
    this.fCancelRequest = true;
  };

  handleChangeStationName = (event) => {
    this.setState({
      strStationName: event.target.value
    });
  };

  render() {
    const tState = this.state.tState;
    let tPage = null;
    if( tState==this.STATE_Started ) {
      tPage = (
        <div>
          <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
            <Typography variant="h2" gutterBottom>Unkonfigurierte Teststation.</Typography>
            <Typography variant="subtitle1" gutterBottom>Diese Teststation ist noch nicht fertig konfiguriert.</Typography>
            <Typography variant="subtitle1" gutterBottom>Die Fehlermeldung ist: <br/><tt>{this.strMessage}</tt></Typography>
          </div>
          <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
            <Typography variant="subtitle1" gutterBottom>Möchtest Du einen neuen Test installieren?</Typography>
            <Button variant="contained" onClick={this.handleInstall}>Install</Button>
          </div>
        </div>
      );
    } else if( tState==this.STATE_SelectSource ) {
      tPage = (
        <div>
          <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
            <Typography variant="h2" gutterBottom>Installationsquelle</Typography>
            <Typography variant="subtitle1" gutterBottom>Du kannst einen Fertigungstest vom Nexus installieren, oder einen Test von Deinem Rechner hochladen.</Typography>
          </div>
          <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
            <form onSubmit={this.handleSelectSource}>
              <FormControl>
                <FormLabel>Wähle die Quelle des Fertigungstests.</FormLabel>
                <RadioGroup value={this.state.strSource} onChange={this.handleSelectSourceRadio}>
                  <FormControlLabel value="nexus" control={<Radio />} label="Nexus" />
                  <FormControlLabel value="local" control={<Radio />} label="Hochladen" />
                </RadioGroup>
                <Button type="submit" variant="contained" color="primary">Ok</Button>
              </FormControl>
            </form>
          </div>
        </div>
      );

    } else if( tState==this.STATE_SourceUpload_SelectFile ) {
      tPage = (
        <div>
          <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
            <Typography variant="h2" gutterBottom>File hochladen.</Typography>
            <Typography variant="subtitle1" gutterBottom>Wähle das File aus, das Du installieren möchtest.</Typography>
          </div>
          <div style={{width: '100%', textAlign: 'center'}}>
            <input type="file" name="file" onChange={this.handleFile} disabled={this.state.fIsUploading==true}/>
          </div>
          <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
            <Button type="submit" variant="contained" color="primary" disabled={this.state.fHaveFile==false || this.state.fIsUploading==true || this.state.fUploadFinished==true} onClick={this.handleFileSubmission}>Submit</Button>
          </div>
          <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
            <LinearProgress variant="determinate" value={this.state.ulProgress*100/this.state.ulFileSize} disabled={this.state.fIsUploading!=true}/>
            <Button variant="contained" disabled={this.state.fIsUploading!=true} onClick={this.handleCancelButton}>Cancel Upload</Button>
          </div>
        </div>
      );

    } else if( tState==this.STATE_SourceNexus_ReceiveList ) {
      tPage = (
        <div>
          <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
            <Typography variant="h2" gutterBottom>Lese die Liste der verfügbaren Tests...</Typography>
          </div>
          <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
            <LinearProgress variant="determinate" value={this.state.ulProgress}/>
            <Button variant="contained" onClick={this.handleCancelButton}>Cancel</Button>
          </div>
        </div>
      );

    } else if( tState==this.STATE_SourceNexus_SelectEntry ) {
      tPage = (
        <div>
          <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
            <Typography variant="h2" gutterBottom>Wähle einen Test aus</Typography>
          </div>
          <div style={{width: '100%', paddingBottom: '3em'}}>
            <TreeView defaultCollapseIcon={<MinusSquare />} defaultExpandIcon={<PlusSquare />} defaultEndIcon={<TreeInstallIcon />}>
              {this.state.atArtifacts.map((atL1, uiL1) => (
                <TreeItem key={uiL1} nodeId={uiL1} label={atL1['l']}>
                  {atL1['i'].map((atL2, uiL2) => (
                    <TreeItem key={uiL1+'_'+uiL2} nodeId={uiL1+'_'+uiL2} label={atL2['l']}>
                      {atL2['i'].map((atL3, uiL3) => (
                        <TreeItem key={uiL1+'_'+uiL2+'_'+uiL3} nodeId={uiL1+'_'+uiL2+'_'+uiL3} label={atL3['l']}>
                          {atL3['i'].map((tAttr, uiL4) => (
                            <TreeItem key={uiL1+'_'+uiL2+'_'+uiL3+'_'+uiL4} nodeId={uiL1+'_'+uiL2+'_'+uiL3+'_'+uiL4} label={tAttr.c} onLabelClick={() => this.onNexusSelect(tAttr)}/>
                          ))}
                        </TreeItem>
                      ))}
                    </TreeItem>
                  ))}
                </TreeItem>
              ))}
            </TreeView>
          </div>
        </div>
      );

    } else if( tState==this.STATE_SourceNexus_Downloading ) {
      tPage = (
        <div>
          <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
            <Typography variant="h2" gutterBottom>Der Test wird heruntergeladen...</Typography>
          </div>
          <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
            <LinearProgress variant="determinate" value={this.state.ulProgress}/>
            <Button variant="contained" onClick={this.handleCancelButton}>Cancel Download</Button>
          </div>
        </div>
      );

    } else if( tState==this.STATE_ConfirmInstall ) {
      const tPackageDetails = this.state.tPackageDetails;
      if(
        tPackageDetails.host.HOST_DISTRIBUTION_ID==tPackageDetails.archive.HOST_DISTRIBUTION_ID &&
        tPackageDetails.host.HOST_DISTRIBUTION_VERSION==tPackageDetails.archive.HOST_DISTRIBUTION_VERSION &&
        tPackageDetails.host.HOST_CPU_ARCHITECTURE==tPackageDetails.archive.HOST_CPU_ARCHITECTURE
      ) {
        tPage = (
          <div>
            <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
              <Typography variant="h2" gutterBottom>Installation bestätigen.</Typography>
              <Typography variant="subtitle1" gutterBottom>Prüfe nochmal alles, und dann kann es schon losgehen.</Typography>
            </div>
            <div style={{width: '100%', textAlign: 'center'}}>
              <TextField
                id="station_name"
                label="Station Name"
                value={this.state.strStationName}
                onChange={this.handleChangeStationName}
                type="string"
                required={true}
                margin="normal"
                style={{width: "95%"}}
              />
            </div>
          </div>
        );
      } else {
        tPage = (
          <div>
            <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
              <Typography variant="h2" gutterBottom>Installation nicht möglich.</Typography>
              <Typography variant="subtitle1" gutterBottom>Der Fertigungstest passt nicht zu dieser Teststation.</Typography>
            </div>
            <div style={{width: '100%', textAlign: 'center', paddingBottom: '3em'}}>
              <table>
                <tr>
                  <th>&nbsp;</th><th>Teststation</th><th>Fertigungstest</th>
                </tr>
                <tr>
                  <th>Distribution ID</th><td>{tPackageDetails.host.HOST_DISTRIBUTION_ID}</td><td>{tPackageDetails.archive.HOST_DISTRIBUTION_ID}</td>
                </tr>
                <tr>
                  <th>Distribution Version</th><td>{tPackageDetails.host.HOST_DISTRIBUTION_VERSION}</td><td>{tPackageDetails.archive.HOST_DISTRIBUTION_VERSION}</td>
                </tr>
                <tr>
                  <th>CPU Architecture</th><td>{tPackageDetails.host.HOST_CPU_ARCHITECTURE}</td><td>{tPackageDetails.archive.HOST_CPU_ARCHITECTURE}</td>
                </tr>
              </table>
            </div>
          </div>
        );
      } 
    } else {

    }

    return tPage;
  }
}
