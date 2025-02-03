import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, DeleteCommand, UpdateCommand, GetCommand, QueryCommand, ScanCommand } from '@aws-sdk/lib-dynamodb';
import {SQSClient, SendMessageCommand} from '@aws-sdk/client-sqs';
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from "@aws-sdk/client-apigatewaymanagementapi";

const dynamoDB = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const sqs = new SQSClient({});
const apiGateway = new ApiGatewayManagementApiClient({
  endpoint: process.env.WEBSOCKET_API_ENDPOINT,
  region: process.env.AWS_REGION
});

const QUEUE_URL = process.env.SQS_QUEUE_URL;
const CONNECTIONS_TABLE = 'KahootConnections';
const GAMES_TABLE = 'KahootGames';
const QUESTIONS_TABLE = 'KahootQuestions';

const QUESTION_IDS = ['q1', 'q2', 'q3'];

// Function to generate a unique ID
// const generateUniqueId = () => {
//   return Date.now().toString(36) + Math.random().toString(36).substr(2);  
// };

export const handler = async (event) => {
    console.log('Received event:', JSON.stringify(event, null, 2));
    
    const routeKey = event.requestContext.routeKey;
    const connectionId = event.requestContext.connectionId;
    console.log('Route Key:', routeKey);
    console.log('Connection Id:', connectionId);
    
    // const body = JSON.parse(event.body || {});
    
    // Parse the role from the WebSocket URL
    // const queryStringParameters = event.queryStringParameters || {};
    // const role = queryStringParameters.role || 'player'; // Default to 'player' if not specified
    // const gameId = queryStringParameters.gameId;

    if (event.body) {
        try {
            console.log('Message body:', JSON.parse(event.body));
        } catch (error) {
            console.error('Error parsing message body:', error);
        }
    }

    try {
        switch (routeKey) {
            case '$connect':
                console.log('Handling $connect');
                return handleConnect(connectionId, event.queryStringParameters);
            
            case '$disconnect':
                console.log('Disconnection:', connectionId);
                return handleDisconnect(connectionId);
            
            case 'initiateGame':
                console.log('Handling initiateGame');
                return await handleInitiateGame(connectionId, JSON.parse(event.body));
            
            case 'checkGameStatus':
                console.log('Handling checkGameStatus');
                return await handleCheckGameStatus(connectionId, JSON.parse(event.body));
            
            case 'checkNickname':
                console.log('Handling checkNickname');
                return await handleCheckNickname(connectionId, JSON.parse(event.body));
      
            case 'joinGame':
                console.log('Handling joinGame');
                return await handleJoinGame(connectionId, JSON.parse(event.body));
            
            case 'startGame':
                console.log('Handling startGame');
                return await handleStartGame(connectionId, JSON.parse(event.body));
            
            case 'nextQuestion':
                console.log('Handling nextQuestion');
                return await handleNextQuestion(connectionId, JSON.parse(event.body));
                
            case 'submitAnswer':
                console.log('Handling submitAnswer');
                return await handleSubmitAnswer(connectionId, JSON.parse(event.body));
            
            case 'endGame':
                console.log('Handling endGame');
                return await handleEndGame(connectionId, JSON.parse(event.body));
                
            default:
                console.log('Unknown route:', routeKey);
                return { statusCode: 400, body: 'Unknown route.' };
        }
    } catch (error) {
        console.error('Error in lambda execution:', error);
        
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Internal server error' })
        };
    }
};

async function handleConnect(connectionId, queryParams) {
    console.log('CONNECTION:', queryParams);
    const { gameId, role } = queryParams || {};
    await dynamoDB.send(new PutCommand({
        TableName: CONNECTIONS_TABLE,
        Item: { 
            connectionId, 
            gameId,
            role,
            timestamp: Date.now()
        }
    }));
    return { statusCode: 200, body: 'Connected.' };
}

async function handleDisconnect(connectionId) {
    await dynamoDB.send(new DeleteCommand({
        TableName: CONNECTIONS_TABLE,
        Key: { connectionId }
    }));
    return { statusCode: 200, body: 'Disconnected.' };
}

async function handleInitiateGame(connectionId, data) {
    console.log('Initiating game:', data);
    const gameId = data.gameId;
    const gameCode = data.gameCode;
    
    if (!gameId) {
        console.error('GameId is missing');
        throw new Error('GameId is required to initiate a game');
    }
    
    // Fetch questions for the game
    const questionsResponse = await dynamoDB.send(new ScanCommand({
        TableName: QUESTIONS_TABLE,
        // You might want to add some filtering or limiting logic here
    }));
    
    const questions = questionsResponse.Items;

    const gameData = {
        gameId,
        gameCode,
        hostConnectionId: connectionId,
        players: [],
        status: 'waiting',
        currentQuestionIndex: -1,
        totalQuestions: questions.length,
        startTime: Date.now(),
        questions: questions.map(q => q.QuestionID) // Store question IDs
    };

    console.log('Attempting to save game data:', JSON.stringify(gameData));

    try {
        await dynamoDB.send(new PutCommand({
            TableName: GAMES_TABLE,
            Item: gameData
        }));
        console.log('Game data saved successfully');
    } catch (error) {
        console.error('Error saving game data:', error);
        throw new Error('Failed to save game data: ' + error.message);
    }

    try {
        const sendData = JSON.stringify({ 
                type: 'gameInitiated', 
                gameCode,
                totalQuestions: questions.length
            })
        console.log('Sending game initiation message to host where data: ',sendData);
        await apiGateway.send(new PostToConnectionCommand({
            ConnectionId: connectionId,
            Data: sendData
        }));
        console.log('Game initiation message sent to host');
    } catch (error) {
        console.error('Error sending game initiation message:', error);
        throw new Error('Failed to send game initiation message: ' + error.message);
    }

    console.log('Game initiated successfully:', gameCode);
    return { statusCode: 200, body: JSON.stringify({ gameId, gameCode, totalQuestions: questions.length }) };
}

async function handleCheckGameStatus(connectionId, data) {
  const { gameCode } = data;
  
  const { Items } = await dynamoDB.send(new QueryCommand({
    TableName: GAMES_TABLE,
    IndexName: 'GameCodeIndex',
    KeyConditionExpression: 'gameCode = :gameCode',
    ExpressionAttributeValues: { ':gameCode': gameCode }
  }));
  
  if (Items.length === 0) {
    await sendWebSocketMessage(connectionId, {
      type: 'error',
      message: 'Game not found.'
    });
    return { statusCode: 404, body: 'Game not found.' };
  }
  
  const game = Items[0];
  
  const checkGame = JSON.stringify({
    type: 'gameStatus',
    status: game.status
  });
  
  await sendWebSocketMessage(connectionId, checkGame);
  
  return { statusCode: 200, body: JSON.stringify({ message: 'Game status sent' }) };
}

async function handleCheckNickname(connectionId, data) {
  const { gameCode, nickname } = data;
  
  const { Items } = await dynamoDB.send(new QueryCommand({
    TableName: GAMES_TABLE,
    IndexName: 'GameCodeIndex',
    KeyConditionExpression: 'gameCode = :gameCode',
    ExpressionAttributeValues: { ':gameCode': gameCode }
  }));
  
  if (Items.length === 0) {
    await sendWebSocketMessage(connectionId, {
      type: 'error',
      message: 'Game not found.'
    });
    return { statusCode: 404, body: 'Game not found.' };
  }
  
  const game = Items[0];
  
  const isNicknameTaken = game.players.some(player => player.nickname.toLowerCase() === nickname.toLowerCase());
  
  const checkNickname = JSON.stringify({
    type: 'nicknameCheck',
    isAvailable: !isNicknameTaken
  });
  
  await sendWebSocketMessage(connectionId, checkNickname);
  
  return { statusCode: 200, body: JSON.stringify({ message: 'Nickname availability sent' }) };
}

async function handleJoinGame(connectionId, data) {
    const { gameCode, nickname } = data;
    
    const { Items } = await dynamoDB.send(new QueryCommand({
        TableName: GAMES_TABLE,
        IndexName: 'GameCodeIndex',
        KeyConditionExpression: 'gameCode = :gameCode',
        ExpressionAttributeValues: { ':gameCode': gameCode }
    }));
    
    if (Items.length === 0) {
        return { statusCode: 404, body: 'Game not found.' };
    }
    
    const game = Items[0];
    const newPlayer = { connectionId, nickname, score: 0 };
    const updatedPlayers = [...game.players, newPlayer];
    
    // if (!gameData.Item || gameData.Item.status !== 'waiting') {
    //     throw new Error('Game not available for joining');
    // }
    
    // const newPlayer = { connectionId, nickname, score: 0 };
    // const updatedPlayers = [...(gameData.Item.players || []), newPlayer];
    
    await dynamoDB.send(new UpdateCommand({
        TableName: GAMES_TABLE,
        Key: { gameId: game.gameId },
        UpdateExpression: 'SET players = :updatedPlayers',
        ExpressionAttributeValues: { ':updatedPlayers': updatedPlayers }
    }));
    
    // Notify host about the new player
    await apiGateway.send(new PostToConnectionCommand({
        ConnectionId: game.hostConnectionId,
        Data: JSON.stringify({ 
            type: 'playerJoined', 
            players: updatedPlayers.map(p => ({ nickname: p.nickname, score: p.score }))
        })
    }));
    
    // Notify the player that they've joined successfully
    await apiGateway.send(new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: JSON.stringify({ type: 'joinedGame', gameId: game.gameId })
    }));
    
    return { statusCode: 200, body: JSON.stringify({ message: 'Joined game successfully' }) };
}

async function handleStartGame(connectionId, data) {
    const { gameId } = data;
    
    const gameData = await dynamoDB.send(new GetCommand({
        TableName: GAMES_TABLE,
        Key: { gameId }
    }));
    
    if (!gameData.Item || gameData.Item.hostConnectionId !== connectionId) {
        throw new Error('Not authorized to start the game');
    }
    
    await dynamoDB.send(new UpdateCommand({
        TableName: GAMES_TABLE,
        Key: { gameId },
        UpdateExpression: 'SET #status = :status, currentQuestionIndex = :questionIndex',
        ExpressionAttributeNames: { '#status': 'status' },
        ExpressionAttributeValues: { 
            ':status': 'active', 
            ':questionIndex': 0
        }
    }));
    
    // Notify all players that the game has started
    for (const player of gameData.Item.players) {
        await apiGateway.send(new PostToConnectionCommand({
            ConnectionId: player.connectionId,
            Data: JSON.stringify({ type: 'gameStarted' })
        }));
    }
    
    // Send the first question
    // await sendQuestionToPlayers(gameId, QUESTION_IDS[0]);
    await sendQuestionToPlayers(gameId, gameData.Item.questions[0], 0);
    
    return { statusCode: 200, body: JSON.stringify({ message: 'Game started successfully' }) };
}

async function handleNextQuestion(connectionId, data) {
  const { gameId } = data;

  const gameData = await dynamoDB.send(new GetCommand({
    TableName: GAMES_TABLE,
    Key: { gameId }
  }));

  if (!gameData.Item || gameData.Item.hostConnectionId !== connectionId) {
    throw new Error('Not authorized to move to next question');
  }

  const currentIndex = gameData.Item.currentQuestionIndex;
  const nextIndex = currentIndex + 1;

  if (nextIndex >= gameData.Item.totalQuestions) {
    // End the game if we've gone through all questions
    return handleEndGame(connectionId, { gameId });
  }

  await dynamoDB.send(new UpdateCommand({
    TableName: GAMES_TABLE,
    Key: { gameId },
    UpdateExpression: 'SET currentQuestionIndex = :questionIndex',
    ExpressionAttributeValues: { ':questionIndex': nextIndex }
  }));

  // Send the next question to all players
  await sendQuestionToPlayers(gameId, gameData.Item.questions[nextIndex], nextIndex);

  return { statusCode: 200, body: JSON.stringify({ message: 'Moving to next question' }) };
}

async function sendQuestionToPlayers(gameId, questionId, questionNumber) {
  const questionStartTime = Date.now();

  // Update the question start time in the database
  await dynamoDB.send(new UpdateCommand({
    TableName: GAMES_TABLE,
    Key: { gameId },
    UpdateExpression: 'SET QuestionStartTime = :startTime',
    ExpressionAttributeValues: { ':startTime': questionStartTime }
  }));

  const gameData = await dynamoDB.send(new GetCommand({
    TableName: GAMES_TABLE,
    Key: { gameId }
  }));

  const questionData = await dynamoDB.send(new GetCommand({
    TableName: QUESTIONS_TABLE,
    Key: { QuestionID: questionId }
  }));

  if (!questionData.Item) {
    throw new Error(`Question not found: ${questionId}`);
  }

  const questionToSend = {
    type: 'newQuestion',
    questionId: questionId,
    questionNumber: questionNumber,
    totalQuestions: gameData.Item.totalQuestions,
    question: questionData.Item.Question,
    options: questionData.Item.Options || []
  };

  // Send question to all players
  for (const player of gameData.Item.players) {
    await apiGateway.send(new PostToConnectionCommand({
      ConnectionId: player.connectionId,
      Data: JSON.stringify(questionToSend)
    }));
  }

  // Send question to host
  await apiGateway.send(new PostToConnectionCommand({
    ConnectionId: gameData.Item.hostConnectionId,
    Data: JSON.stringify({
      type: 'newQuestion',
      questionId: questionId,
      questionNumber: questionNumber,
      totalQuestions: gameData.Item.totalQuestions,
      question: questionData.Item.Question
    })
  }));
}

async function handleSubmitAnswer(connectionId, data) {
    console.log('Handling submit answer:', data);
    const { gameCode, nickname, questionId, answer } = data;
    const answerTime = Date.now(); // Capture the exact time the answer was received

    // First we need to get the gameId using the gameCode
    const { Items } = await dynamoDB.send(new QueryCommand({
        TableName: GAMES_TABLE,
        IndexName: 'GameCodeIndex',
        KeyConditionExpression: 'gameCode = :gameCode',
        ExpressionAttributeValues: { ':gameCode': gameCode }
    }));
    
    if (Items.length === 0) {
        return { statusCode: 404, body: 'Game not found' };
    }
    
    const game = Items[0];
    const gameId = game.gameId;

    try {
        const player = game.players.find(p => p.connectionId === connectionId);
        if (!player) {
            throw new Error('Player not found in game');
        }

        // Prepare the message for SQS
        const message = JSON.stringify({
            connectionId,
            nickname,
            gameId,
            gameCode,
            questionId,
            answer,
            answerTime,
            timestamp: Date.now()
        });

        // Send the message to SQS
        await sqs.send(new SendMessageCommand({
            QueueUrl: QUEUE_URL,
            MessageBody: message
        }));

        console.log('Answer queued for processing:', message);

        return { 
            statusCode: 200, 
            body: JSON.stringify({ message: 'Answer submitted successfully' })
        };
    } catch (error) {
        console.error('Error handling submit answer:', error);
        return { 
            statusCode: 500, 
            body: JSON.stringify({ error: 'Failed to submit answer', details: error.message })
        };
    }
}

async function handleEndGame(connectionId, data) {
  console.log('Handling end game:', data);
  const { gameId } = data;

  try {
    const gameData = await dynamoDB.send(new GetCommand({
      TableName: GAMES_TABLE,
      Key: { gameId }
    }));

    if (!gameData.Item) {
      throw new Error('Game not found');
    }

    if (gameData.Item.hostConnectionId !== connectionId) {
      throw new Error('Not authorized to end the game');
    }

    // Prepare the final leaderboard
    const leaderboard = gameData.Item.players
      .map(player => ({ nickname: player.nickname, score: player.score || 0 }))
      .sort((a, b) => b.score - a.score);

    // Update game status
    await dynamoDB.send(new UpdateCommand({
      TableName: GAMES_TABLE,
      Key: { gameId },
      UpdateExpression: 'SET #status = :status, endTime = :endTime',
      ExpressionAttributeNames: { '#status': 'status' },
      ExpressionAttributeValues: { 
        ':status': 'ended',
        ':endTime': Date.now()
      }
    }));

    // Notify all players that the game has ended
    const endGameMessage = JSON.stringify({
      type: 'gameEnded',
      leaderboard: leaderboard
    });

    // const sendEndGameMessage = async (connectionId) => {
    //   try {
    //     await apiGateway.send(new PostToConnectionCommand({
    //       ConnectionId: connectionId,
    //       Data: endGameMessage
    //     }));
    //   } catch (error) {
    //     console.error(`Failed to send end game message to ${connectionId}:`, error);
    //   }
    // };

    // // Send end game message to all players and the host
    // await Promise.all([
    //   ...gameData.Item.players.map(player => sendEndGameMessage(player.connectionId)),
    //   sendEndGameMessage(gameData.Item.hostConnectionId)
    // ]);

    // console.log('Game ended successfully:', gameId);
      
    console.log('ENDGAME function -- handleWebSocket');
    for (const player of gameData.Item.players) {
      await sendWebSocketMessage(player.connectionId, endGameMessage);
    }
      
    await sendWebSocketMessage(gameData.Item.hostConnectionId, endGameMessage);
      
    return { statusCode: 200, body: JSON.stringify({ message: 'Game ended successfully' }) };
  } catch (error) {
    console.error('Error ending game:', error);
    return { statusCode: 500, body: JSON.stringify({ error: 'Failed to end game', details: error.message }) };
  }
}

async function sendWebSocketMessage(connectionId, message) {
  try {
    await apiGateway.send(new PostToConnectionCommand({
      ConnectionId: connectionId,
      Data: message
    }));
  } catch (error) {
    console.error(`Failed to send message to ${connectionId}:`, error);
  }
}