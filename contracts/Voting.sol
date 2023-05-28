//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;
//will use Counter for counters.counter from the counter library  
//which will be used to  assign unique ids to candidate  and increment it
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// We import this library to be able to use console.log
import "hardhat/console.sol";
//we're inheriting from the "Ownable" contract so we dont write boilerplate code and do some ownership restriction
contract Voting is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter public candidateIds;
    //these are the struct defining the candidate and the voter 
    struct Candidate {
        string firstName;
        string lastName;
        uint voteCount;
    }
    struct Voter {
        string Name;
        uint id;
        bool hasVoted;
    }
    //these var to store the winner  candidate later on when the vote is finished
    Candidate public winner;
    //public mapiing to indicate registred candidates
    mapping(bytes32 => bool) public isCandidateRegistered;
    //This is a private mapping that associates a candidate ID  with a Candidate struct. 
    //It allows accessing candidate details using their ID
    mapping(uint => Candidate) private idToCandidate;
    //these mapping used later to make sure that a voter can vote twice
    mapping(bytes32 => bool) private isRegistered;
    mapping(bytes32 => Voter) private hashToVoter;
    //this enum to present the  voting phases
    enum Stage {
        INITIALIZED,
        STARTED,
        FINISHED
    }
    Stage public VotingStage;
    //these are vents emmitted  to inform external entites about changes if candidate is registred for ex
    event CandidateRegistered(string firstName, string lastName, uint id);
    event VoterRegistered(string firstName, uint id);
    event WinnerAnnounced(string firstName, string lastName, uint voteCount);
    //this is to tell that once the contract is deployed the voting phase would be intializd 
    constructor() {
        VotingStage = Stage.INITIALIZED;
    }
  //these dunction are only called by the owner (organizer) to change the vote stage 
    function startVoting() public onlyOwner {
        VotingStage = Stage.STARTED;
    }

    function stopVoting() public onlyOwner {
        VotingStage = Stage.FINISHED;
    }
     // this is function to register candidate and only used by the owner 
     //which will take first  name and last name as parameters 
    function registerCandidate(
        string calldata _firstName,
        string calldata _lastName
    ) public onlyOwner {
        require(
            VotingStage == Stage.INITIALIZED,
            "Voting stage should be INITIALIZED"
        );
        bytes32 hash = keccak256(abi.encode(_firstName, _lastName));
        require(!isCandidateRegistered[hash], "Candidate already registered");
        uint candidateId = candidateIds.current();
        console.log("CandidateId", candidateId);
        idToCandidate[candidateId] = Candidate(_firstName, _lastName, 0);
        candidateIds.increment();
        isCandidateRegistered[hash] = true;
        emit CandidateRegistered(_firstName, _lastName, candidateId);
    }
 // this function is used to register voter can be called by anyone  takes two parameters name and id
    function registerVoter(
        string calldata _Name,
        uint _id
    ) public {
        if (VotingStage != Stage.FINISHED) {
            require(
                !isVoterRegistered(_Name, _id),
                "Voter already registered"
            );
            bytes32 hash = keccak256(abi.encode(_Name, _id));
            hashToVoter[hash] = Voter(_Name, _id, false);
            isRegistered[hash] = true;
            emit VoterRegistered(_Name, _id);
        }
    }
    
    function finishVoting() public onlyOwner {
        require(VotingStage == Stage.STARTED, "Voting has not been started");
        Candidate memory candidate;
        for (uint i = 0; i < candidateIds.current(); i++) {
            if (idToCandidate[i].voteCount > candidate.voteCount) {
                candidate = idToCandidate[i];
            }
        }

        VotingStage = Stage.FINISHED;
        winner = candidate;
        emit WinnerAnnounced(
            candidate.firstName,
            candidate.lastName,
            candidate.voteCount
        );
    }
    //this function to announce the winner of the vote
    function getWinner() public view returns (Candidate memory) {
        return winner;
    }
   // function to vote can be called by anyone
    function vote(
        uint _id,
        string calldata _voterName,
        uint _voterid
    ) public {
        require(VotingStage == Stage.STARTED, "Voting has not been started");
        require(
            isVoterRegistered(_voterName, _voterid),
            "Voter not registered"
        );
        require(!hasVoted(_voterName, _voterid), "Voter has voted");
        Candidate memory candidate = idToCandidate[_id];
        candidate.voteCount += 1;
        idToCandidate[_id] = candidate;
        bytes32 hash = keccak256(abi.encode(_voterName, _voterid));
        hashToVoter[hash].hasVoted = true;
    }
      // function to display candidate and their ids and vootecount
    function getCandidates() public view returns (Candidate[] memory) {
        Candidate[] memory candidates = new Candidate[](candidateIds.current());
        console.log(candidateIds.current());
        for (uint i = 0; i < candidateIds.current(); i++) {
            candidates[i] = idToCandidate[i];
        }
        return candidates;
    }
     //function to  see if voter is already registerd or not 
     //keccak256 to save gas  the comparais of hash better than string 
    function isVoterRegistered(
        string calldata _Name,
        uint _id
    ) public view returns (bool) {
        bytes32 hash = keccak256(abi.encode(_Name, _id));
        return isRegistered[hash];
    }
     // this function used to make sure that once voter has voted he cant vote again by returning a true 
    function hasVoted(
        string calldata _Name,
        uint _id
    ) public view returns (bool) {
        bytes32 hash = keccak256(abi.encode(_Name, _id));
        Voter memory voter = hashToVoter[hash];
        return voter.hasVoted;
    }
}