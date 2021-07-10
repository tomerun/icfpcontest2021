import {atom} from 'recoil';
import {Input, Vertex} from './models';
import {getDist, getSafeRange} from './utility';

const scoreData = atom({
    key: 'scoreData',
    default: {
        edgeData: [] as EdgeData[],
        valid:false,
        dislike: -1,
    } as Score,
});

interface EdgeData {
    vertex: [number, number],
    dist: number,
    valid: boolean,
    ratio: number,
};

interface Score {
    edgeData: EdgeData[],
    valid: boolean,
    dislike: number,
};

const calcScore = (input:Input, vertex: Vertex[]) => {
    const k = Number(1000000);
    const edgeData = input.figure.edges.map(e => {
        const [i,j] = e;
        const d0 = getDist(
            input.figure.vertices[i],
            input.figure.vertices[j]);
        const d1 = getDist(
            vertex[i].pos,
            vertex[j].pos);
        
        const [lb, ub] = getSafeRange(d0, input.epsilon);
        
        return {
            vertex: e,
            dist: d1,
            valid: lb <= d1*k && d1*k <= ub,
            ratio: d1 / d0 - 1.0,
        };
    });
    
    const valid = edgeData.filter(e => !e.valid).length == 0;
    
    const dislike = input.hole.map(p => 
        Math.min(...vertex.map(v => getDist(v.pos, p)))
    ).reduce((s,x) => s+x, 0);

    const res: Score = {
        edgeData,
        valid,
        dislike: dislike,
    };
    return res;
}

export { calcScore, scoreData };
export type { Score, EdgeData };
