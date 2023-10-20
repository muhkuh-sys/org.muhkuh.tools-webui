./.install_build_requirements
npm install
npm run release
tar cfvz targets/webpage.tar.gz targets/www
./build_artifact.py