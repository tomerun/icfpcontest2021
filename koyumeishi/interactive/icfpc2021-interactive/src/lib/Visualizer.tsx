import { useEffect} from 'react';
import {selector, useRecoilValue, useSetRecoilState} from 'recoil';
import {Button, Row, Form, Col} from 'react-bootstrap';

import {Input, Output} from './models';
import {initialOutputState, inputState, outputState} from './TextArea';
import {vis, startVisualize, render, setHint, updateVertexState} from './VisualizerCore';
import {scoreData} from './Score';
import {adjust} from './physicModel';

const inputData = selector({
    key: 'inputData',
    get: ({get}) => {
        let res = JSON.parse(get(inputState)) as Input;
        return res;
    },
});

const Visualizer = () => {
    const input = useRecoilValue(inputData);
    const initialOutputStr = useRecoilValue(initialOutputState);
    const outputSetter = useSetRecoilState(outputState);
    const scoreDataSetter = useSetRecoilState(scoreData);
    
    let initialOutput: Output;
    
    try{
        initialOutput = JSON.parse(initialOutputStr) as Output;
    }catch(e){
        initialOutput = {vertices: [...input.figure.vertices]};
    }

    const adjustButtonOnClick = () => {
        adjust();
        render();
    };

    const hintIdChanged = (id: number) => {
        setHint(id);
        render();
    };

    useEffect(() => {
        startVisualize(
            input,
            initialOutput,
            outputSetter,
            scoreDataSetter);
    });
    return (
        <>
            <Row className="mycanvas">
                <canvas id="canvas" width="600" height="600"></canvas>
            </Row>
            <Row>
                <Col>
                    <Button onClick={adjustButtonOnClick}>
                        Adjust
                    </Button>
                </Col>
                <Col>
                    <Button onClick={(e)=>{
                        try{
                            if(vis.history.length > 1){
                                vis.history.pop();
                                updateVertexState(
                                    [...vis.history[vis.history.length-1]],
                                    false
                                );
                                render();
                            }
                        }catch(e){

                        }
                    }}>
                        Undo
                    </Button>
                </Col>
                <Form>
                    <Form.Label>Hint Edge Id</Form.Label>
                    <Form.Control as="select" onChange={(e) => hintIdChanged(parseInt(e.target.value))}>
                        {input.figure.edges.map((e, i) => (
                            <option key={i}>{i}</option>
                        ))}
                    </Form.Control> 
                </Form>
            </Row>
        </>
    );
};


export {Visualizer};
