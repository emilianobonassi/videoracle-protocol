// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Address } from "openzeppelin-contracts/contracts/utils/Address.sol";

contract Videoracle {

    uint256 constant TOTAL_VOTES = 5;

    enum QuestionStatus { ACTIVE, VOTING, CLOSED }
    struct Question {
        uint256 endTime;
        uint256 reward;
        QuestionStatus status;
        address questioner;
        string questionURI;
    }

    mapping(uint256 => Question) public questions;
    uint256 public questionsCount;

    struct Answer {
        uint256 answerVideoId;
        address payable answerer;
    }

    mapping(uint256 => mapping(uint256 => Answer)) public answersByQuestion;
    mapping(uint256 => uint256) public answersCount4Question;
    mapping(uint256 => mapping(uint256 => uint256)) public pointsForAnswer4Question;
    mapping(uint256 => mapping(uint256 => bool)) public claimedAnswer4Question;

    function askQuestion(uint256 time2answer, uint256 reward, string calldata questionURI) public payable returns(uint256 questionId) {
        require(msg.value >= reward, 'value sent not enough');

        questionId = questionsCount++;
        questions[questionId] = Question({
            endTime: block.timestamp + time2answer,
            reward: reward,
            status: QuestionStatus.ACTIVE,
            questioner: msg.sender,
            questionURI: questionURI
        });

        if (msg.value > reward) {
            Address.sendValue(payable(msg.sender),  msg.value-reward);
        }
    }

    function answerQuestion(uint256 questionId, uint256 answerVideoId) public returns(uint256 answerId) {
        require(questionId < questionsCount, 'question does not exist');

        Question memory question = questions[questionId];

        require(question.questioner != msg.sender, 'you cannot answer your own question');

        require(question.status == QuestionStatus.ACTIVE, 'question not in active state');

        answerId = answersCount4Question[questionId]++;

        answersByQuestion[questionId][answerId] = Answer({
            answerVideoId: answerVideoId,
            answerer: payable(msg.sender)
        });
    }

    function voteAnswers(uint256 questionId, uint256[] calldata answersIds, uint256[] calldata points) public {
        require(answersIds.length == points.length, 'check answersIds and points');

        Question storage question = questions[questionId];

        require(question.questioner == msg.sender, 'only answerer can vote their own questions');

        if (question.status == QuestionStatus.ACTIVE && question.endTime >= block.timestamp) {
            question.status = QuestionStatus.VOTING;
        }

        require(question.status == QuestionStatus.VOTING, 'question not in voting state');

        uint256 totalVotes = 0;
        for(uint256 i = 0; i < answersIds.length; i++) {
            uint256 answerPoints = points[i];
            totalVotes += answerPoints;
            pointsForAnswer4Question[questionId][answersIds[i]] = answerPoints;
        }

        require(totalVotes <= TOTAL_VOTES, 'too many votes');

        question.status = QuestionStatus.CLOSED;
    }

    function claim(uint256 questionId, uint256 answerId) public {
        uint256 points = pointsForAnswer4Question[questionId][answerId];
        require(points > 0, 'no points to your question');

        require(claimedAnswer4Question[questionId][answerId] == false, 'already claimed');

        claimedAnswer4Question[questionId][answerId] = true;

        uint256 answerReward = questions[questionId].reward * points / TOTAL_VOTES;

        Address.sendValue(
            (answersByQuestion[questionId][answerId]).answerer,
            answerReward
        );
    }
}
