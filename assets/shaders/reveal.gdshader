shader_type canvas_item;

// Efeito "preto e branco -> colorido" usado nas miniaturas da Vitrine do Supermercado.
// Aplique esse shader num TextureRect/Sprite2D com a MESMA imagem da versão
// cinza por baixo (ou simplesmente use isso sozinho: ele já desatura o que
// ainda não foi revelado). progress vai de 0.0 (tudo cinza) a 1.0 (tudo colorido).

uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = vec3(gray) * 0.55; // também escurece um pouco, como no protótipo web
	// Revela da esquerda pra direita conforme "progress" (equivalente ao
	// clip-path: inset(0 X% 0 0) usado na versão web).
	float reveal_edge = progress;
	vec3 final_color = mix(desaturated, tex.rgb, step(UV.x, reveal_edge));
	COLOR = vec4(final_color, tex.a);
}
