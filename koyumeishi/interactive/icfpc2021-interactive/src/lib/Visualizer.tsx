import { useEffect} from 'react';
import {selector, useRecoilValue, useSetRecoilState} from 'recoil';
import {Button, Row, Form, FormGroup, FormLabel} from 'react-bootstrap';

import {Input, Output} from './models';
import {inputState, outputState} from './TextArea';
import {vis, startVisualize, render, setHint} from './VisualizerCore';
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
    const outputSetter = useSetRecoilState(outputState);
    const scoreDataSetter = useSetRecoilState(scoreData);
    
    let initialOutput: Output = {vertices: [...input.figure.vertices]};

    const adjustButtonOnClick = () => {
        vis.vertex = adjust(vis.input, vis.vertex);
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
                <Button onClick={adjustButtonOnClick}>
                    Adjust
                </Button>
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
