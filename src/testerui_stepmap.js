import React from 'react';



class TesterUIStepMap extends React.Component {
  constructor(props) {
    super(props);

    this.state = {};

    const astrImages = {
      idle: '#cow_untested',
      ok: '#cow_ok',
      error: '#cow_failed',
      disabled: '#cow_disabled',
      excluded: '#cow_excluded'
    };
    this.astrImages = astrImages;
  }


  render() {
    const uiNumberOfTests = this.props.astrTestNames.length;

    let tTestStepMap = null;
    if( uiNumberOfTests>0 ) {
      /* The 0 based index of te running test. If no test is running, it is "null". */
      const uiRunningTest = this.props.uiRunningTest;

      /* X and Y size of the cow heads in pixels.
        NOTE: This must match the size and viewBox of the cow head symbols.
      */
      const uiCowHeadSizeXPx = 240;
      const uiCowHeadSizeYPx = 240;

      const uiBackgroundCircleOffsetXPx = -8;
      const uiBackgroundCircleOffsetYPx = 0;
      const uiBackgroundCircleRadiusPx = 110;

      const uiProgressIndicatorOffsetXPx = 12;
      const uiProgressIndicatorOffsetYPx = 20;

      const strViewBox = '0 0 ' + (uiNumberOfTests*uiCowHeadSizeXPx).toString() + ' ' + uiCowHeadSizeYPx.toString();

      let tLineStepConnector = null;
      let atBackgroundCircles = null;
      let atCowHeads = null;
      let tProgressIndicator = null;
      let atToolTips = null;

      /* Create a line connecting all test steps. */
      tLineStepConnector = (
        <line x1={uiCowHeadSizeXPx/2}
              y1={uiCowHeadSizeYPx/2}
              x2={uiNumberOfTests*uiCowHeadSizeXPx - (uiCowHeadSizeXPx/2)}
              y2={uiCowHeadSizeYPx/2}
              style={{stroke: '#000', strokeWidth: 6}}
        />
      );

      /* Create all layers. This is...
       *   * the circles for the background of the cow heads
       *   * the cow heads
       *   * the progress indicator
       *   * the invisible areas for the tooltip
       */
      atBackgroundCircles = [];
      atCowHeads = [];
      atToolTips = [];
      this.props.astrTestNames.forEach(function(strStepTitle, uiStepIndex) {
        atBackgroundCircles.push(
          <circle cx={uiStepIndex*uiCowHeadSizeXPx + uiCowHeadSizeXPx/2 + uiBackgroundCircleOffsetXPx}
                  cy={uiCowHeadSizeYPx/2 + uiBackgroundCircleOffsetYPx}
                  r={uiBackgroundCircleRadiusPx}
                  fill="#fff"
                  style={{stroke: '#000', strokeWidth: 6}}
                  key={'backgroundcircle'+uiStepIndex}
          />
        );

        const strState = this.props.atTestStati[uiStepIndex];
        const strImgId = this.astrImages[strState];
        atCowHeads.push(
          <use href={strImgId}
               x={uiStepIndex*uiCowHeadSizeXPx}
               y={0}
               key={'cow'+uiStepIndex}
          />
        );

        if( uiStepIndex===uiRunningTest ) {
          tProgressIndicator = (
            <use href="#progress"
                 x={uiStepIndex*uiCowHeadSizeXPx + uiProgressIndicatorOffsetXPx}
                 y={uiProgressIndicatorOffsetYPx}
                 key={'progress'+uiStepIndex}
            />
          );
        }

        atToolTips.push(
          <circle cx={uiStepIndex*uiCowHeadSizeXPx + uiCowHeadSizeXPx/2 + uiBackgroundCircleOffsetXPx}
                  cy={uiCowHeadSizeYPx/2 + uiBackgroundCircleOffsetYPx}
                  r={uiBackgroundCircleRadiusPx}
                  fill="#0000"
                  style={{stroke: '#0000'}}
                  key={'progress'+uiStepIndex}
          >
            <title>{strStepTitle}</title>
          </circle>
        );
      }, this);

      tTestStepMap = (
        <svg style={{height: this.props.strIconSize, width: '100%', backgroundColor: '#777'}}
             viewBox={strViewBox}
             preserveAspectRatio="xMidYMid meet"
        >
          <defs>

            <clipPath id="ue">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-35 69 197 98-98 197-197-98z"/>
            </clipPath>
            <clipPath id="ud">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="M0 81h212v230H0z" transform="rotate(-20) skewX(5)"/>
            </clipPath>
            <clipPath id="ua">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="M0 77h220v220H0z"/>
            </clipPath>
            <clipPath id="uc">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-12 76 218 33-33 218-218-33z"/>
            </clipPath>
            <clipPath id="ub">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-15 76 216 42-42 216-216-43z"/>
            </clipPath>

            <clipPath id="od">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-35 69 197 98-98 197-197-98z"/>
            </clipPath>
            <clipPath id="oc">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="M0 81h212v230H0z" transform="rotate(-20) skewX(5)"/>
            </clipPath>
            <clipPath id="ob">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-12 76 218 33-33 218-218-33z"/>
            </clipPath>
            <clipPath id="oe">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-12 76 218 33-33 218-218-33z"/>
            </clipPath>
            <clipPath id="oa">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="M0 77h220v220H0z"/>
            </clipPath>

            <clipPath id="fe">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-35 69 197 98-98 197-197-98z"/>
            </clipPath>
            <clipPath id="fd">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="M0 81h212v230H0z" transform="rotate(-20) skewX(5)"/>
            </clipPath>
            <clipPath id="fa">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="M0 77h220v220H0z"/>
            </clipPath>
            <clipPath id="fc">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-12 76 218 33-33 218-218-33z"/>
            </clipPath>
            <clipPath id="fb">
              <path stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-15 76 216 42-42 216-216-43z"/>
            </clipPath>

            <clipPath id="de">
              <path stroke="#aeaeae" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-35 69 197 98-98 197-197-98z"/>
            </clipPath>
            <clipPath id="dd">
              <path stroke="#aeaeae" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="M0 81h212v230H0z" transform="rotate(-20) skewX(5)"/>
            </clipPath>
            <clipPath id="da">
              <path stroke="#aeaeae" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="M0 77h220v220H0z"/>
            </clipPath>
            <clipPath id="dc">
              <path stroke="#aeaeae" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-12 76 218 33-33 218-218-33z"/>
            </clipPath>
            <clipPath id="db">
              <path stroke="#aeaeae" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-15 76 216 42-42 216-216-43z"/>
            </clipPath>

            <clipPath id="ee">
              <path stroke="#aeaeae" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-35 69 197 98-98 197-197-98z"/>
            </clipPath>
            <clipPath id="ed">
              <path stroke="#aeaeae" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="M0 81h212v230H0z" transform="rotate(-20) skewX(5)"/>
            </clipPath>
            <clipPath id="ea">
              <path stroke="#aeaeae" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="M0 77h220v220H0z"/>
            </clipPath>
            <clipPath id="ec">
              <path stroke="#aeaeae" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-12 76 218 33-33 218-218-33z"/>
            </clipPath>
            <clipPath id="eb">
              <path stroke="#aeaeae" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="m-15 76 216 42-42 216-216-43z"/>
            </clipPath>
          </defs>

          <symbol id="cow_untested" width="240px" height="240px" viewBox="0 0 240 240">
            <g fillRule="evenodd">
              <path fill="#fff" stroke="#000" strokeWidth="2.8" d="m75 320 10-52h64l10 50z" clipPath="url(#ua)" transform="translate(0 -77)"/>
              <path fill="#dbdbdb" stroke="#000" strokeWidth="2.8" d="M144 274s26 2 32-2c16-11 1-17-3-17l-30 2c-19 0-32 5-40 7l-25 8c-6 2-12 16 6 16 0 0 6 0 29-8 16-6 31-6 31-6z" clipPath="url(#ua)" transform="translate(0 -77)"/>
              <path fill="#868686" stroke="#010000" strokeWidth="1.4" d="M79 114C66 74 90 97 91 99z" clipPath="url(#ua)" transform="translate(0 -77)"/>
              <path fill="#868686" stroke="#000" strokeWidth="1.4" d="M106 96c19-29 14 12 15 10z" clipPath="url(#ua)" transform="translate(0 -77)"/>
            </g>
            <g stroke="#000" strokeLinecap="round">
              <path fill="#fff" strokeLinejoin="round" strokeWidth="2.8" d="M57 205s18 1 21-40c4-41-12-39-12-39s-10-3-29 15l-8 8s-8 10-10-3c-4-28 27-25 34-25 23 0 25-10 25-10s4-12 19-14c20-3 19 1 31 14 9 1 35-16 35-16s16-5 17 10c-1 1 7 13-49 13 0 0 8 68 41 73l-59 44z" clipPath="url(#ua)" transform="translate(0 -77)"/>
              <path fill="#fff" strokeWidth="1.5" d="M57 173a28 17 0 0 1-32-14 28 17 0 0 1 24-19 28 17 0 0 1 32 14 28 17 0 0 1-24 19" clipPath="url(#ub)" transform="rotate(-11 -396 -38)"/>
              <path strokeWidth="1.2" d="M92 146a4 4 0 0 1-4-3 4 4 0 0 1 3-4 4 4 0 0 1 4 3 4 4 0 0 1-3 4" clipPath="url(#ua)" transform="translate(0 -77)"/>
              <path fill="#fff" strokeWidth="1.5" d="M108 165a17 12 0 0 1-19-10 17 12 0 0 1 14-13 17 12 0 0 1 19 10 17 12 0 0 1-14 13" clipPath="url(#uc)" transform="rotate(-8.7 -506 -37)"/>
              <path strokeWidth="1.2" d="M125 140a4 4 0 0 1-5-3 4 4 0 0 1 3-4 4 4 0 0 1 5 3 4 4 0 0 1-3 4" clipPath="url(#ua)" transform="translate(0 -77)"/>
            </g>
            <path fill="none" stroke="#000" strokeLinecap="round" strokeWidth="2.1" d="M152 108c13-8 18-9 18-3M46 127c-24 1-20 13-20 13" clipPath="url(#ua)" transform="translate(0 -77)"/>
            <g stroke="#000">
              <path fill="#dbdbdb" fillRule="evenodd" strokeWidth="2.8" d="M198 236s19-42-20-45c-24-4-37 16-63 18-24 2-23-15-63-2-44 18-9 56-9 56s19 18 57 3c24-14 51-9 51-9 39 0 47-21 47-21z" clipPath="url(#ua)" transform="translate(0 -77)"/>
              <path fill="#a4a4a4" strokeLinecap="round" strokeWidth="2.1" d="M255 140a10 5 0 0 1-11-4 10 5 0 0 1 8-6 10 5 0 0 1 12 4 10 5 0 0 1-9 6" clipPath="url(#ud)" transform="matrix(.95 .33 -.43 .9 0 -77)"/>
              <path fill="#a4a4a4" strokeLinecap="round" strokeWidth="2.1" d="M-49 234a12 7 0 0 1-13-6 12 7 0 0 1 9-8 12 7 0 0 1 14 6 12 7 0 0 1-10 8" clipPath="url(#ue)" transform="rotate(-27 -163 -39)"/>
            </g>
            <path fill="#fff" d="M34 212a22 22 0 0 1-26-18 22 22 0 0 1 19-26 22 22 0 0 1 25 19 22 22 0 0 1-18 25"/>
            <path fill="none" d="M0 160h60v60H0z"/>
            <path d="M27 205h5v-5h-5zm3-40a25 25 0 1 0 0 50 25 25 0 0 0 0-50zm0 45a20 20 0 1 1 0-40 20 20 0 0 1 0 40zm0-35c-6 0-10 4-10 10h5c0-3 2-5 5-5s5 2 5 5c0 5-8 4-8 13h5c0-6 8-7 8-13s-4-10-10-10z"/>
          </symbol>

          <symbol id="cow_ok" width="240px" height="240px" viewBox="0 0 240 240">
            <path fill="#7fff7f" fillRule="evenodd" stroke="#000" strokeWidth="2.8" d="m75 320 10-52h64l10 50z" clipPath="url(#oa)" transform="translate(2 -77)"/>
            <path fill="#7fff7f" stroke="#000" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.8" d="M71 179h96v23H71z"/>
            <path fill="none" stroke="#000" strokeWidth="2.8" d="M90 178v26m19-26v26m19-26v26m20-26v26"/>
            <g fillRule="evenodd">
              <path fill="#6cd96c" stroke="#000" strokeWidth="2.8" d="M144 274s26 2 32-2c16-11 1-17-3-17l-30 2c-19 0-32 5-40 7l-25 8c-6 2-12 16 6 16 0 0 6 0 29-8 16-6 31-6 31-6z" clipPath="url(#oa)" transform="scale(1 -1) rotate(11 2590 -13)"/>
              <path fill="#2b562b" stroke="#010000" strokeWidth="1.4" d="M79 114C66 74 90 97 91 99z" clipPath="url(#oa)" transform="rotate(8 652 167)"/>
              <path fill="#2b562b" stroke="#000" strokeWidth="1.4" d="M106 96c19-29 14 12 15 10z" clipPath="url(#oa)" transform="rotate(8 652 167)"/>
            </g>
            <g stroke="#000" strokeLinecap="round">
              <path fill="#7fff7f" strokeLinejoin="round" strokeWidth="2.8" d="M57 205s18 1 21-40c4-41-12-39-12-39s-10-3-29 15l-8 8s-8 10-10-3c-4-28 27-25 34-25 23 0 25-10 25-10s4-12 19-14c20-3 19 1 31 14 9 1 35-16 35-16s16-5 17 10c-1 1 7 13-49 13 0 0 8 68 41 73l-59 44z" clipPath="url(#oa)" transform="rotate(8 652 167)"/>
              <path fill="#7fff7f" strokeWidth="1.3" d="M108 165a17 12 0 0 1-19-10 17 12 0 0 1 14-13 17 12 0 0 1 19 10 17 12 0 0 1-14 13" clipPath="url(#ob)" transform="rotate(-1 -9427 -3196)"/>
            </g>
            <path fill="none" stroke="#000" strokeLinecap="round" strokeWidth="2.1" d="M152 108c13-8 18-9 18-3M46 127c-24 1-20 13-20 13" clipPath="url(#oa)" transform="rotate(8 652 167)"/>

            <g stroke="#000">
              <path fill="#6cd96c" fillRule="evenodd" strokeWidth="2.8" d="M198 236s19-42-20-45c-24-4-37 16-63 18-24 2-23-15-63-2-44 18-9 56-9 56s19 18 57 3c24-14 51-9 51-9 39 0 47-21 47-21z" clipPath="url(#oa)" transform="rotate(8 652 167)"/>
              <g strokeLinecap="round">
                <path fill="#4f9f4f" strokeWidth="2.1" d="M255 140a10 5 0 0 1-11-4 10 5 0 0 1 8-6 10 5 0 0 1 12 4 10 5 0 0 1-9 6" clipPath="url(#oc)" transform="rotate(27 202 17) skewX(-7)"/>
                <path fill="#4f9f4f" strokeWidth="2.1" d="M-49 234a12 7 0 0 1-13-6 12 7 0 0 1 9-8 12 7 0 0 1 14 6 12 7 0 0 1-10 8" clipPath="url(#od)" transform="rotate(-18 -264 -139)"/>
                <ellipse fill="#7fff7f" strokeWidth="1.3" cx="93" cy="61" rx="17" ry="12"/>
                <circle stroke="#000" cx="98" cy="61" r="4"/>
                <ellipse fill="#7fff7f" strokeWidth="1.3" cx="139" cy="61" rx="17" ry="12"/>
                <circle stroke="#000" cx="134" cy="61" r="4"/>
              </g>
            </g>

            <path fill="#7fff7f" d="M33 212a22 22 0 0 1-25-19 22 22 0 0 1 19-25 22 22 0 0 1 25 18 22 22 0 0 1-18 26"/>
            <path fill="none" d="M0 160h60v60H0zh60v60H0z"/>
            <path d="m41 179-16 16-9-9-4 4 13 13 20-20zm-11-14a25 25 0 1 0 0 50 25 25 0 0 0 0-50zm0 45a20 20 0 1 1 0-40 20 20 0 0 1 0 40z"/>
          </symbol>

          <symbol id="cow_failed" width="240px" height="240px" viewBox="0 0 240 240">
            <g fillRule="evenodd">
              <path fill="#fa7d7d" stroke="#000" strokeWidth="2.8" d="m75 320 10-52h64l10 50z" clipPath="url(#fa)" transform="translate(-5 -77)"/>
              <path fill="#d96c6c" stroke="#000" strokeWidth="2.8" d="M144 274s26 2 32-2c16-11 1-17-3-17l-30 2c-19 0-32 5-40 7l-25 8c-6 2-12 16 6 16 0 0 6 0 29-8 16-6 31-6 31-6z" clipPath="url(#fa)" transform="rotate(9 585 149)"/>
              <path fill="#562b2b" stroke="#010000" strokeWidth="1.4" d="M79 114C66 74 90 97 91 99z" clipPath="url(#fa)" transform="rotate(9 585 149)"/>
              <path fill="#562b2b" stroke="#000" strokeWidth="1.4" d="M106 96c19-29 14 12 15 10z" clipPath="url(#fa)" transform="rotate(9 585 149)"/>
            </g>
            <g stroke="#000" strokeLinecap="round">
              <path fill="#fa7d7d" strokeLinejoin="round" strokeWidth="2.8" d="M57 205s18 1 21-40c4-41-12-39-12-39s-4-1-24 22l-8 7s-13 7-12-5c1-20 23-27 31-29 14-3 25-10 25-10s4-12 19-14c20-3 19 1 31 14l42 3s6 1 8 11c0 0 5 8-47-7 0 0 8 68 41 73l-59 44z" clipPath="url(#fa)" transform="rotate(9 585 149)"/>
              <path fill="#fa7d7d" strokeWidth="1.5" d="M54 173a28 17 0 0 1-32-14 28 17 0 0 1 24-19 28 17 0 0 1 32 14 28 17 0 0 1-24 19" clipPath="url(#fb)" transform="rotate(-91 26 91)"/>
              <path strokeWidth="1.2" d="M92 146a4 4 0 0 1-4-3 4 4 0 0 1 3-4 4 4 0 0 1 4 3 4 4 0 0 1-3 4" clipPath="url(#fa)" transform="rotate(9 585 149)"/>
              <path fill="#fa7d7d" strokeWidth="1.5" d="M106 163a17 12 0 0 1-19-10 17 12 0 0 1 14-13 17 12 0 0 1 19 10 17 12 0 0 1-14 13" clipPath="url(#fc)" transform="rotate(-92 77 93)"/>
              <path strokeWidth="1.2" d="M125 140a4 4 0 0 1-5-3 4 4 0 0 1 3-4 4 4 0 0 1 5 3 4 4 0 0 1-3 4" clipPath="url(#fa)" transform="rotate(9 585 149)"/>
            </g>
            <path fill="none" stroke="#000" strokeLinecap="round" strokeWidth="2.1" d="M152 108c14-7 14-7 18-5" clipPath="url(#fa)" transform="rotate(41.357 235 92)"/>
            <path fill="none" stroke="#000" strokeLinecap="round" strokeWidth="2.1" d="M46 127c-18 0-22 11-22 11" clipPath="url(#fa)" transform="rotate(-17 -225 62)"/>
            <g stroke="#000">
              <path fill="#d96c6c" fillRule="evenodd" strokeWidth="2.8" d="M198 236s19-42-20-45c-24-4-37 16-63 18-24 2-23-15-63-2-44 18-9 56-9 56s19 18 57 3c24-14 51-9 51-9 39 0 47-21 47-21z" clipPath="url(#fa)" transform="rotate(9 585 149)"/>
              <path fill="#9f4f4f" strokeLinecap="round" strokeWidth="2.1" d="M255 142a10 5 0 0 1-11-4 10 5 0 0 1 8-6 10 5 0 0 1 12 4 10 5 0 0 1-9 6" clipPath="url(#fd)" transform="matrix(.88 .47 -.57 .82 32 -92)"/>
              <path fill="#9f4f4f" strokeLinecap="round" strokeWidth="2.1" d="M-49 234a12 7 0 0 1-13-6 12 7 0 0 1 9-8 12 7 0 0 1 14 6 12 7 0 0 1-10 8" clipPath="url(#fe)" transform="rotate(-17 -287 -150)"/>
            </g>
            <path fill="#fa7d7d" d="M34 212a22 22 0 0 1-26-18 22 22 0 0 1 19-26 22 22 0 0 1 25 19 22 22 0 0 1-18 25"/>
            <path fill="none" d="M0 160h60v60H0z"/>
            <path d="M27 198h5v5h-5zm0-20h5v15h-5zm3-13a25 25 0 1 0 0 50 25 25 0 0 0 0-50zm0 45a20 20 0 1 1 0-40 20 20 0 0 1 0 40z"/>
          </symbol>

          <symbol id="cow_disabled" width="240px" height="240px" viewBox="0 0 240 240">
            <g stroke="#aeaeae">
              <g fillRule="evenodd">
                <path fill="#e3e3e3" strokeWidth="2.8" d="m75 320 10-52h64l10 50z" clipPath="url(#da)" transform="translate(0 -77)"/>
                <path fill="#e3e3e3" strokeWidth="2.8" d="M144 274s26 2 32-2c16-11 1-17-3-17l-30 2c-19 0-32 5-40 7l-25 8c-6 2-12 16 6 16 0 0 6 0 29-8 16-6 31-6 31-6z" clipPath="url(#da)" transform="translate(0 -77)"/>
                <path fill="#cecece" strokeWidth="1.4" d="M79 114C66 74 90 97 91 99zm27-18c19-29 14 12 15 10z" clipPath="url(#da)" transform="translate(0 -77)"/>
              </g>
              <g strokeLinecap="round">
                <path fill="#e3e3e3" strokeLinejoin="round" strokeWidth="2.8" d="M57 205s18 1 21-40c4-41-12-39-12-39s-10-3-29 15l-8 8s-8 10-10-3c-4-28 27-25 34-25 23 0 25-10 25-10s4-12 19-14c20-3 19 1 31 14 9 1 35-16 35-16s16-5 17 10c-1 1 7 13-49 13 0 0 8 68 41 73l-59 44z" clipPath="url(#da)" transform="translate(0 -77)"/>
                <path fill="#e3e3e3" strokeWidth="1.5" d="M57 173a28 17 0 0 1-32-14 28 17 0 0 1 24-19 28 17 0 0 1 32 14 28 17 0 0 1-24 19" clipPath="url(#db)" transform="rotate(-11 -396 -38)"/>
                <path fill="#aeaeae" strokeWidth="1.2" d="M92 146a4 4 0 0 1-4-3 4 4 0 0 1 3-4 4 4 0 0 1 4 3 4 4 0 0 1-3 4" clipPath="url(#da)" transform="translate(0 -77)"/>
                <path fill="#e3e3e3" strokeWidth="1.5" d="M108 165a17 12 0 0 1-19-10 17 12 0 0 1 14-13 17 12 0 0 1 19 10 17 12 0 0 1-14 13" clipPath="url(#dc)" transform="rotate(-8.7 -506 -37)"/>
                <path fill="#aeaeae" strokeWidth="1.2" d="M125 140a4 4 0 0 1-5-3 4 4 0 0 1 3-4 4 4 0 0 1 5 3 4 4 0 0 1-3 4" clipPath="url(#da)" transform="translate(0 -77)"/>
              </g>
              <path fill="none" strokeLinecap="round" strokeWidth="2.1" d="M152 108c13-8 18-9 18-3M46 127c-24 1-20 13-20 13" clipPath="url(#da)" transform="translate(0 -77)"/>
              <path fill="#e3e3e3" fillRule="evenodd" strokeWidth="2.8" d="M198 236s19-42-20-45c-24-4-37 16-63 18-24 2-23-15-63-2-44 18-9 56-9 56s19 18 57 3c24-14 51-9 51-9 39 0 47-21 47-21z" clipPath="url(#da)" transform="translate(0 -77)"/>
              <path fill="#d6d6d6" strokeLinecap="round" strokeWidth="2.1" d="M255 140a10 5 0 0 1-11-4 10 5 0 0 1 8-6 10 5 0 0 1 12 4 10 5 0 0 1-9 6" clipPath="url(#dd)" transform="matrix(.95 .33 -.43 .9 0 -77)"/>
              <path fill="#d6d6d6" strokeLinecap="round" strokeWidth="2.1" d="M-49 234a12 7 0 0 1-13-6 12 7 0 0 1 9-8 12 7 0 0 1 14 6 12 7 0 0 1-10 8" clipPath="url(#de)" transform="rotate(-27 -163 -39)"/>
            </g>
            <path fill="none" stroke="#ff8080" strokeLinecap="round" strokeWidth="8" d="M32 192 192 32"/>
          </symbol>

          <symbol id="cow_excluded" width="240px" height="240px" viewBox="0 0 240 240">
            <g stroke="#aeaeae">
              <g fillRule="evenodd">
                <path fill="#e3e3e3" strokeWidth="2.8" d="m75 320 10-52h64l10 50z" clipPath="url(#ea)" transform="translate(0 -77)"/>
                <path fill="#e3e3e3" strokeWidth="2.8" d="M144 274s26 2 32-2c16-11 1-17-3-17l-30 2c-19 0-32 5-40 7l-25 8c-6 2-12 16 6 16 0 0 6 0 29-8 16-6 31-6 31-6z" clipPath="url(#ea)" transform="translate(0 -77)"/>
                <path fill="#cecece" strokeWidth="1.4" d="M79 114C66 74 90 97 91 99zm27-18c19-29 14 12 15 10z" clipPath="url(#ea)" transform="translate(0 -77)"/>
              </g>
              <g strokeLinecap="round">
                <path fill="#e3e3e3" strokeLinejoin="round" strokeWidth="2.8" d="M57 205s18 1 21-40c4-41-12-39-12-39s-10-3-29 15l-8 8s-8 10-10-3c-4-28 27-25 34-25 23 0 25-10 25-10s4-12 19-14c20-3 19 1 31 14 9 1 35-16 35-16s16-5 17 10c-1 1 7 13-49 13 0 0 8 68 41 73l-59 44z" clipPath="url(#ea)" transform="translate(0 -77)"/>
                <path fill="#e3e3e3" strokeWidth="1.5" d="M57 173a28 17 0 0 1-32-14 28 17 0 0 1 24-19 28 17 0 0 1 32 14 28 17 0 0 1-24 19" clipPath="url(#eb)" transform="rotate(-11 -396 -38)"/>
                <path fill="#aeaeae" strokeWidth="1.2" d="M92 146a4 4 0 0 1-4-3 4 4 0 0 1 3-4 4 4 0 0 1 4 3 4 4 0 0 1-3 4" clipPath="url(#em)" transform="translate(0 -77)"/>
                <path fill="#e3e3e3" strokeWidth="1.5" d="M108 165a17 12 0 0 1-19-10 17 12 0 0 1 14-13 17 12 0 0 1 19 10 17 12 0 0 1-14 13" clipPath="url(#ec)" transform="rotate(-8.7 -506 -37)"/>
                <path fill="#aeaeae" strokeWidth="1.2" d="M125 140a4 4 0 0 1-5-3 4 4 0 0 1 3-4 4 4 0 0 1 5 3 4 4 0 0 1-3 4" clipPath="url(#ea)" transform="translate(0 -77)"/>
              </g>
              <path fill="none" strokeLinecap="round" strokeWidth="2.1" d="M152 108c13-8 18-9 18-3M46 127c-24 1-20 13-20 13" clipPath="url(#ea)" transform="translate(0 -77)"/>
              <path fill="#e3e3e3" fillRule="evenodd" strokeWidth="2.8" d="M198 236s19-42-20-45c-24-4-37 16-63 18-24 2-23-15-63-2-44 18-9 56-9 56s19 18 57 3c24-14 51-9 51-9 39 0 47-21 47-21z" clipPath="url(#ea)" transform="translate(0 -77)"/>
              <path fill="#d6d6d6" strokeLinecap="round" strokeWidth="2.1" d="M255 140a10 5 0 0 1-11-4 10 5 0 0 1 8-6 10 5 0 0 1 12 4 10 5 0 0 1-9 6" clipPath="url(#ed)" transform="matrix(.95 .33 -.43 .9 0 -77)"/>
              <path fill="#d6d6d6" strokeLinecap="round" strokeWidth="2.1" d="M-49 234a12 7 0 0 1-13-6 12 7 0 0 1 9-8 12 7 0 0 1 14 6 12 7 0 0 1-10 8" clipPath="url(#ee)" transform="rotate(-27 -163 -39)"/>
            </g>
            <path fill="none" stroke="#ff8080" strokeLinecap="round" strokeWidth="8" d="M48 32H32v160h16M176 32h16v160h-16"/>
          </symbol>

          <symbol id="progress" width="200px" height="200px" viewBox="0 0 200 200">
            <circle className="cow_progress_path" cx="100" cy="100" r="96" fill="none" strokeWidth="7" strokeMiterlimit="50"></circle>
          </symbol>

          {tLineStepConnector}
          {atBackgroundCircles}
          {atCowHeads}
          {tProgressIndicator}
          {atToolTips}
        </svg>
      );
    }

    return (
      <div>
        {tTestStepMap}
      </div>
    );
  }
}

export default TesterUIStepMap
