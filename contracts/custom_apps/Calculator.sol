pragma solidity ^0.4.15;

import "../apps/AragonApp.sol";

contract Calculator is AragonApp {

    bytes32 public constant ADD_NUMBER_ROLE = keccak256("ADD_NUMBER_ROLE");
    bytes32 public constant REMOVE_NUMBER_ROLE = keccak256("REMOVE_NUMBER_ROLE");

    // The Calculator number
    uint public number;

    // Fired when a number is added
    event NumberAdded(uint number);
    // Fired when an entry is removed from the registry.
    event NumberRemoved(uint number);

    function initialize() onlyInit external {
        initialized();
    }

    /**
     * Add a value
     * @param _num The number to add
     */
    function add (uint _num) public auth(ADD_NUMBER_ROLE) {
        number += _num;

        NumberAdded(_num);
    }

    /**
     * Remove a value
     * @param _num The number to remove
     */
    function remove(uint _num) public auth(REMOVE_NUMBER_ROLE) {

        require(number >= _num);
        number -= _num;

        NumberRemoved(_num);
    }

    function getNumber() public constant returns (uint _num) {
        _num = number;
    }

}