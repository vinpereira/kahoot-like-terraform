import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, PutCommand, UpdateCommand, ScanCommand } from '@aws-sdk/lib-dynamodb';
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from '@aws-sdk/client-apigatewaymanagementapi';

const dynamoDB = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const apiGateway = new ApiGatewayManagementApiClient({
    endpoint: process.env.WEBSOCKET_API_ENDPOINT
    // endpoint: process.env.WEBSOCKET_API_ENDPOINT_LAMBDA
});

const GAMES_TABLE = 'KahootGames';
const ANSWERS_TABLE = 'KahootAnswers';
const QUESTIONS_TABLE = 'KahootQuestions';

const MAX_SCORE = 1000;
const MIN_SCORE = 100;
const SCORE_DECREASED_PER_SECOND = 100;
const STREAK_BONUS = 100;
const ANSWER_TIMEOUT = 30000; // 30 seconds timeout for answers

export const handler = async (event) => {
  for (const record of event.Records) {
    const { connectionId, nickname, gameId, questionId, answer, answerTime } = JSON.parse(record.body);
    console.log('Processing answer:', { connectionId, nickname, gameId, questionId, answer, answerTime });

    try {
      // Store or update the answer in KahootAnswers table
      await dynamoDB.send(new PutCommand({
        TableName: ANSWERS_TABLE,
        Item: {
          gameId_playerId: `${gameId}_${connectionId}`,
          questionId,
          answer,
          answerTime,
          nickname
        }
      }));

      // Check if all players have answered
      const gameData = await dynamoDB.send(new GetCommand({
        TableName: GAMES_TABLE,
        Key: { gameId },
        ConsistentRead: true
      }));

      if (!gameData.Item) {
        throw new Error('Game not found');
      }

      const totalPlayers = gameData.Item.players.length;
      const answersData = await dynamoDB.send(new ScanCommand({
        TableName: ANSWERS_TABLE,
        FilterExpression: 'begins_with(gameId_playerId, :gameId) AND questionId = :questionId',
        ExpressionAttributeValues: {
          ':gameId': gameId,
          ':questionId': questionId
        }
      }));

      const currentAnswers = answersData.Items;

      if (currentAnswers.length === totalPlayers) {
        // All players have answered, calculate scores
        await calculateScoresAndDistributeResults(gameId, questionId, currentAnswers, gameData.Item);
      }

      // Send acknowledgment to the player
      await apiGateway.send(new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: JSON.stringify({ type: 'answerReceived' })
      }));

    } catch (error) {
      console.error('Error processing answer:', error);
    }
  }

  return { statusCode: 200, body: 'Processing complete' };
};

async function calculateScoresAndDistributeResults(gameId, questionId, answers, gameData) {
  // Fetch correct answer and calculate scores
  const questionData = await dynamoDB.send(new GetCommand({
    TableName: QUESTIONS_TABLE,
    Key: { QuestionID: questionId }
  }));

  const correctAnswer = questionData.Item.CorrectAnswer;
  const questionStartTime = gameData.QuestionStartTime;
  const updatedPlayers = gameData.players.map(player => {
    const playerAnswer = answers.find(a => a.gameId_playerId === `${gameId}_${player.connectionId}`);
    if (playerAnswer) {
      const isCorrect = playerAnswer.answer === correctAnswer;
      const timeTaken = Math.min((playerAnswer.answerTime - questionStartTime) / 1000, ANSWER_TIMEOUT / 1000);
      const { baseScore, streakBonus, totalScore } = calculateScore(isCorrect, timeTaken, player.currentStreak || 0);
      return {
        ...player,
        score: (player.score || 0) + totalScore,
        currentStreak: isCorrect ? (player.currentStreak || 0) + 1 : 0,
        lastAnswerResult: {
          isCorrect,
          playerAnswer: playerAnswer.answer,
          correctAnswer,
          timeTaken,
          baseScore,
          streakBonus,
          totalScore
        }
      };
    }
    return { ...player, currentStreak: 0, lastAnswerResult: null };
  });

  // Sort players by score
  updatedPlayers.sort((a, b) => b.score - a.score);

  // Find player with highest streak
  const highestStreakPlayer = updatedPlayers.reduce((prev, current) => 
    (current.currentStreak > prev.currentStreak || 
    (current.currentStreak === prev.currentStreak && current.score > prev.score)) ? current : prev
  );

  // Send results to each player
  for (let i = 0; i < updatedPlayers.length; i++) {
    const player = updatedPlayers[i];
    await apiGateway.send(new PostToConnectionCommand({
      ConnectionId: player.connectionId,
      Data: JSON.stringify({
        type: 'roundResult',
        playerResult: {
          ...player.lastAnswerResult,
          playerAnswer: player.lastAnswerResult.playerAnswer,
          correctAnswer: player.lastAnswerResult.correctAnswer
        },
        totalScore: player.score,
        position: i + 1,
        totalPlayers: updatedPlayers.length,
        isHighestStreakPlayer: player.connectionId === highestStreakPlayer.connectionId
      })
    }));
  }

  // Send top 3 players and highest streak player to host
  const top3Players = updatedPlayers.slice(0, 3).map(p => ({ nickname: p.nickname, score: p.score }));
  await apiGateway.send(new PostToConnectionCommand({
    ConnectionId: gameData.hostConnectionId,
    Data: JSON.stringify({
      type: 'roundEnded',
      topPlayers: top3Players,
      highestStreakPlayer: {
        nickname: highestStreakPlayer.nickname,
        streak: highestStreakPlayer.currentStreak
      },
      currentQuestion: gameData.currentQuestionIndex,
      totalQuestions: gameData.totalQuestions
    })
  }));

  // Update game state
  await dynamoDB.send(new UpdateCommand({
    TableName: GAMES_TABLE,
    Key: { gameId },
    // UpdateExpression: 'SET players = :players, currentQuestionIndex = currentQuestionIndex + :inc, lastAnswerProcessed = :lastAnswerProcessed',
    UpdateExpression: 'SET players = :players, currentQuestionIndex = :currentQuestionIndex, lastAnswerProcessed = :lastAnswerProcessed',
    ExpressionAttributeValues: {
      ':players': updatedPlayers,
      // ':inc': 1,
      ':currentQuestionIndex': gameData.currentQuestionIndex,
      ':lastAnswerProcessed': Date.now()
    }
  }));

  // Check if this was the last question
  console.log('CURRENT QUESTION INDEX:', gameData.currentQuestionIndex);
  console.log('TOTAL QUESTIONS:', gameData.totalQuestions);
  // if (gameData.currentQuestionIndex >= gameData.totalQuestions - 1) {
  //   console.log('GOT QUESTION INDEX:', gameData.currentQuestionIndex);
  //   console.log('GOT TOTAL QUESTIONS:', gameData.totalQuestions);
  //   await endGame(gameId, updatedPlayers, gameData.hostConnectionId);
  // } else {
  if (gameData.currentQuestionIndex < gameData.totalQuestions - 1) {
    // Prepare for next question
    await dynamoDB.send(new UpdateCommand({
      TableName: GAMES_TABLE,
      Key: { gameId },
      UpdateExpression: 'SET QuestionStartTime = :questionStartTime',
      ExpressionAttributeValues: {
        ':questionStartTime': Date.now()
      }
    }));
  }
}

function calculateScore(isCorrect, timeTaken, currentStreak) {
  if (!isCorrect) return { baseScore: 0, streakBonus: 0, totalScore: 0 };
  
  const baseScore = Math.max(MIN_SCORE, Math.round(MAX_SCORE - (SCORE_DECREASED_PER_SECOND * timeTaken)));
  const streakBonus = currentStreak > 0 ? STREAK_BONUS * currentStreak : 0;
  const totalScore = baseScore + streakBonus;
  
  return { baseScore, streakBonus, totalScore };
}

// async function endGame(gameId, players, hostConnectionId) {
//   // Send final leaderboard to all players and host
//   console.log('ENDGAME function -- sqsProcessor');
//   const finalLeaderboard = players.map((p, index) => ({
//     nickname: p.nickname,
//     score: p.score,
//     position: index + 1
//   }));

//   for (const player of players) {
//     await apiGateway.send(new PostToConnectionCommand({
//       ConnectionId: player.connectionId,
//       Data: JSON.stringify({
//         type: 'gameEnded',
//         leaderboard: finalLeaderboard
//       })
//     }));
//   }

//   await apiGateway.send(new PostToConnectionCommand({
//     ConnectionId: hostConnectionId,
//     Data: JSON.stringify({
//       type: 'gameEnded',
//       leaderboard: finalLeaderboard
//     })
//   }));

//   // Update game state to ended
//   await dynamoDB.send(new UpdateCommand({
//     TableName: GAMES_TABLE,
//     Key: { gameId },
//     UpdateExpression: 'SET gameStatus = :status',
//     ExpressionAttributeValues: {
//       ':status': 'ended'
//     }
//   }));
// }