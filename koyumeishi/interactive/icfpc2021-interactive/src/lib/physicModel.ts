import {Input, Vertex} from './models';
import { getDist, getSafeRange, getPosFunc } from './utility';
import {vis, moveVertex, updateVertexState} from './VisualizerCore';

const adjust = () => {
    let {input, vertex} = vis;
    const k = 1000000;

    let alpha = 0.00005;
    const thr = 0.2;
    const max_itr = 200;
    
    const [convertPosCanvToOrig] = getPosFunc(input);
    const lb = convertPosCanvToOrig(5, 5)[0];
    const ub = convertPosCanvToOrig(595, 595)[0];

    for(let itr=0; itr<max_itr; itr++){
        let ax = vertex.map(_ => 0.0);
        let ay = vertex.map(_ => 0.0);
    
        input.figure.edges.forEach(p => {
            const [i, j] = p;
            const d0 = getDist(
                input.figure.vertices[i],
                input.figure.vertices[j]);
            const d1 = getDist(
                vertex[i].pos,
                vertex[j].pos);
            
            const [lb, ub] = getSafeRange(d0, input.epsilon);
            
            const dd = d1 - d0;

            const v = [
                (vertex[j].pos[0] - vertex[i].pos[0]),
                (vertex[j].pos[1] - vertex[i].pos[1]),
            ];
            
            const f = [
                v[0]*dd,
                v[1]*dd,
            ];
            
            if(d1*k < lb || d1*k > ub){
                ax[j] += f[0];
                ay[j] += f[1];
                ax[i] -= f[0];
                ay[i] -= f[1];
            }        
        });

        let ok = true;
        vertex = vertex.map((v, i) => {
            if(v.fixed) return v;
            const dx = ax[i] > thr ? -1 : ax[i] < -thr ? +1 : 0;
            const dy = ay[i] > thr ? -1 : ay[i] < -thr ? +1 : 0;
            if(dx !== 0 || dy !== 0){
                ok = false;
            }
            if(Math.random() < 0.3){
                if(Math.random() < 0.5){
                    return moveVertex(v, dx, 0);
                }else{
                    return moveVertex(v, 0, dy);
                }
            }
            return v;
        });
        if(ok) break;
    }
    
    updateVertexState(
        vertex.map(v => {
            return {
                ...v,
                pos: [
                    clamp(lb, ub, v.pos[0]),
                    clamp(lb, ub, v.pos[1]),
                ],
            }
        }),
        true
    );
};

const clamp = (lb: number, ub: number, x: number) => {
    return Math.min(ub, Math.max(lb, x));
};

export {adjust};