import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, ScanCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({});
const dynamoDB = DynamoDBDocumentClient.from(client);

const QUESTIONS_TABLE = 'KahootQuestions';

export const handler = async (event) => {
    // Handle warm-up call
    // if (event.action === 'warmup') {
    //     console.log('Warm-up call received');
    //     return { statusCode: 200, body: 'Warmed up' };
    // }
    
    const params = {
        TableName: QUESTIONS_TABLE,
    };

    try {
        const { Items } = await dynamoDB.send(new ScanCommand(params));
        const questions = Items.map(item => ({
            id: item.QuestionID,
            question: item.Question,
            options: item.Options,
        }));

        return {
            statusCode: 200,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Credentials': true,
            },
            body: JSON.stringify(questions),
        };

    } catch (error) {
        console.error('Error fetching questions:', error);

        return {
            statusCode: 500,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Credentials': true,
            },
            body: JSON.stringify({ error: 'Failed to fetch questions' }),
        };
    }
};