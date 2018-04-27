pragma solidity 0.4.18;

import "../apps/AragonApp.sol";

import "../common/IForwarder.sol";

import "../lib/minime/MiniMeToken.sol";
import "../lib/zeppelin/math/SafeMath.sol";
import "../lib/zeppelin/math/SafeMath64.sol";
import "../lib/misc/Migrations.sol";
import "../acl/ACL.sol";


contract Democracy is IForwarder, AragonApp {

    bytes32 constant public CITIZEN_ROLE = keccak256("CITIZEN_ROLE");
    bytes32 constant public CREATE_VOTES_ROLE = keccak256("CREATE_VOTES_ROLE");

    enum VoterState { Yea, Nay }

    struct Vote {
        address creator;
        uint64 startDate;
        uint256 snapshotBlock;
        uint256 minAcceptQuorumPct;
        uint256 yea;
        uint256 nay;
        uint256 numRequired;
        string metadata;
        bytes executionScript;
        bool executed;
        mapping (address => VoterState) voters;
    }

    Vote[] votes;
    uint256 numCitizens;

    event StartVote(uint256 indexed voteId);
    event CastVote(uint256 indexed voteId, address indexed voter, bool supports);
    event ExecuteVote(uint256 indexed voteId);

    /**
    * @notice Create a new vote about "`_metadata`"
    * @param _executionScript EVM script to be executed on approval
    * @return voteId id for newly created vote
    */
    function newVote(bytes _executionScript, string _metadata, uint _numRequired) auth(CREATE_VOTES_ROLE) external returns (uint256 voteId) {
        return _newVote(_executionScript, _metadata, _numRequired);
    }

    /**
    * @notice Vote `_supports ? 'yay' : 'nay'` in vote #`_voteId`
    * @param _voteId Id for vote
    * @param _supports Whether voter supports the vote
    * @param _executesIfDecided Whether it should execute the vote if it becomes decided
    */
    function vote(uint256 _voteId, bool _supports, bool _executesIfDecided) auth(CITIZEN_ROLE) external {
        require(canVote(_voteId, msg.sender));
        _vote(
            _voteId,
            _supports,
            msg.sender,
            _executesIfDecided
        );
    }

    /**
    * @notice Execute the result of vote #`_voteId`
    * @param _voteId Id for vote
    */
    function executeVote(uint256 _voteId) external {
        require(canExecute(_voteId));
        _executeVote(_voteId);
    }

    function isForwarder() public pure returns (bool) {
        return true;
    }

    /**
    * @notice Creates a vote to execute the desired action
    * @dev IForwarder interface conformance
    * @param _evmScript Start vote with script
    */
    function forward(bytes _evmScript) public {
        require(canForward(msg.sender, _evmScript));
        _newVote(_evmScript, "");
    }

    function canForward(address _sender, bytes _evmCallScript) public view returns (bool) {
        return canPerform(_sender, CREATE_VOTES_ROLE, arr());
    }

    function canVote(uint256 _voteId, address _voter) public view returns (bool) {
        Vote storage vote = votes[_voteId];

        return _isVoteOpen(vote);
    }

    function canExecute(uint256 _voteId) public view returns (bool) {
        Vote storage vote = votes[_voteId];

        if (vote.executed)
            return false;

        // vote ended?
        if (_isVoteOpen(vote))
            return false;

        // has over 50%?
        if (vote.yea < getAuthorized() / 2)
            return false;

        return true;
    }

    function getVote(uint256 _voteId) public view returns (bool open, bool executed, address creator, uint64 startDate, uint256 snapshotBlock, uint256 yea, uint256 nay, uint256 numRequired, bytes script) {
        Vote storage vote = votes[_voteId];

        open = _isVoteOpen(vote);
        executed = vote.executed;
        creator = vote.creator;
        startDate = vote.startDate;
        snapshotBlock = vote.snapshotBlock;
        yea = vote.yea;
        nay = vote.nay;
        numRequired = vote.numRequired;
        script = vote.executionScript;
    }

    function getVoteMetadata(uint256 _voteId) public view returns (string) {
        return votes[_voteId].metadata;
    }

    function getVoterState(uint256 _voteId, address _voter) public view returns (VoterState) {
        return votes[_voteId].voters[_voter];
    }

    function _newVote(bytes _executionScript, string _metadata) isInitialized internal returns (uint256 voteId) {
        voteId = votes.length++;
        Vote storage vote = votes[voteId];
        vote.executionScript = _executionScript;
        vote.creator = msg.sender;
        vote.startDate = uint64(now);
        vote.metadata = _metadata;
        vote.snapshotBlock = getBlockNumber() - 1; // avoid double voting in this very block

        StartVote(voteId);

        if (canVote(voteId, msg.sender)) {
            _vote(
                voteId,
                true,
                msg.sender,
                true
            );
        }
    }

    function _vote(
        uint256 _voteId,
        bool _supports,
        address _voter,
        bool _executesIfDecided
    ) internal
    {
        Vote storage vote = votes[_voteId];

        // if voter had previously voted, decrease count
        if (state == VoterState.Yea)
            vote.yea = vote.yea.sub(1);
        if (state == VoterState.Nay)
            vote.nay = vote.nay.sub(1);

        if (_supports)
            vote.yea = vote.yea.add(1);
        else
            vote.nay = vote.nay.add(1);

        vote.voters[_voter] = _supports ? VoterState.Yea : VoterState.Nay;

        CastVote(
            _voteId,
            _voter,
            _supports
        );

        if (_executesIfDecided && canExecute(_voteId))
            _executeVote(_voteId);
    }

    function _executeVote(uint256 _voteId) internal {
        Vote storage vote = votes[_voteId];

        vote.executed = true;

        bytes memory input = new bytes(0); // TODO: Consider input for voting scripts
        runScript(vote.executionScript, input, new address[](0));

        ExecuteVote(_voteId);
    }

    function _isVoteOpen(Vote storage vote) internal view returns (bool) {
        return uint64(now) < (vote.startDate.add(voteTime)) && !vote.executed;
    }

}