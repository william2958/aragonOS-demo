pragma solidity ^0.4.18;

import "./AppStorage.sol";
import "../common/Initializable.sol";
import "../evmscript/EVMScriptRunner.sol";
import "../acl/ACLSyntaxSugar.sol";


// ACLSyntaxSugar and EVMScriptRunner are not directly used by this contract, but are included so
// that they are automatically usable by subclassing contracts
contract AragonApp is AppStorage, Initializable, ACLSyntaxSugar, EVMScriptRunner {
    modifier auth(bytes32 _role) {
        require(canPerform(msg.sender, _role, new uint256[](0)));
        _;
    }

    modifier authP(bytes32 _role, uint256[] params) {
        require(canPerform(msg.sender, _role, params));
        _;
    }

    function canPerform(address _sender, bytes32 _role, uint256[] params) public view returns (bool) {
        bytes memory how; // no need to init memory as it is never used
        if (params.length > 0) {
            uint256 byteLength = params.length * 32;
            assembly {
                how := params // forced casting
                mstore(how, byteLength)
            }
        }
        return address(kernel) == 0 || kernel.hasPermission(_sender, address(this), _role, how);
    }

    function getAuthorized(address _sender, bytes32 _role) public view returns (uint) {
        if (address(kernel) == 0) {
            return 0;
        } else {
            return kernel.numAuthorized(_sender, address(this), _role);
        }
    }
}
