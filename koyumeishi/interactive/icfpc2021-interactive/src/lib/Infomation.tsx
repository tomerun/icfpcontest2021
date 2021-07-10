import {Row, Col} from 'react-bootstrap';

import {useRecoilValue} from 'recoil';
import {scoreData} from './Score';

const Infomation = ({}) => {
    const data = useRecoilValue(scoreData);

    const edges = data.edgeData.map((e,i) => {
        const className = e.valid ? "validEdge" : "invalidEdge";
        return (
            <Row>
                <Col>
                    edge: {`${i}`} ( `{e.vertex[0]} -- {e.vertex[1]}` )
                </Col>
                <Col>
                    dist: {`${e.dist}`}, ratio: {`${e.ratio.toFixed(3)}`}
                </Col>
            </Row>
        );
    });
    return (
        <Row style={{overflow: "scroll", height: "600px"}}>
            <Row>
                <Col>dislike: {`${data.dislike}`}</Col>
                <Col>isValie: {`${data.valid}`}</Col>
            </Row>
            {edges}
        </Row>
    );
};

export {Infomation};