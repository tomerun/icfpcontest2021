"use strict";
const problem = document.getElementById("problem")
const solution = document.getElementById("solution")
const start = document.getElementById("start")
const canvas = document.getElementById("canvas")
const margin = 10

start.onclick = (event) => {
	show()
}

function show() {
	const hole = JSON.parse(problem.value).hole
	const vertices = JSON.parse(solution.value).vertices
	const edges = JSON.parse(problem.value).figure.edges
	const max_coord = hole.concat(vertices).reduce((a, p)=> {
		return Math.max(a, p[0], p[1])
	}, 10)
	const drawScale = (canvas.width - margin * 2) / max_coord
	const ctx = canvas.getContext('2d'); 
	ctx.fillStyle = '#AAAAAA'
	ctx.fillRect(0, 0, canvas.width, canvas.height)
	ctx.strokeStyle = 'black'
	ctx.fillStyle = 'white'
	ctx.scale(drawScale, drawScale)
	ctx.lineWidth = 1.0 / drawScale
	const margin_scaled = margin / drawScale
	ctx.beginPath()
	ctx.moveTo(margin_scaled + hole[hole.length - 1][0], margin_scaled + hole[hole.length - 1][1])
	hole.forEach((p) => {
		ctx.lineTo(margin_scaled + p[0], margin_scaled + p[1])
	})
	ctx.closePath()
	ctx.stroke()
	ctx.fill()

	ctx.strokeStyle = 'red'
	ctx.beginPath()
	edges.forEach((e) => {
		const v1 = vertices[e[0]]	
		const v2 = vertices[e[1]]	
		ctx.moveTo(margin_scaled + v1[0], margin_scaled + v1[1])
		ctx.lineTo(margin_scaled + v2[0], margin_scaled + v2[1])
	})
	ctx.stroke()
	ctx.resetTransform()
}
