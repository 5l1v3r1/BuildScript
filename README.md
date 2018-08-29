# BuildScript
A script which helps to find the external dependencies for a given package during a build session .

## Informations
  
  - This is a alpha version of the script, it probably contains many bugs as it not finished
  - Feel free to help me by opening issues in order to improve the script
  - **IMPORTANT**: If i would have been allowed to do it in **Perl**, i would probably have already finished it.


## Usage

  ```bash
     
     Usage:
     sh build_check.sh --dependency="<PACKAGE>-<VERSION>-<NUM>.<PLATFORM>.<ARCH>.<EXTENSION>"

     Example:
     sh build_check.sh --dependency="jws-application-servers-3.1.0-40.sun10.sparc64.zip"

  ```


## Output
  
  <p>
    <img src="https://raw.githubusercontent.com/gottburgm/BuildScript/master/screenshots/example1.png" style="position: center"; />
  </p>
