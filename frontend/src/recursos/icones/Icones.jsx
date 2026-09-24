// Ícones do Bootstrap Icons (https://icons.getbootstrap.com) como componentes.
// Usam "currentColor": pegam a cor do texto de onde estiverem.

export function IconePesquisa({ tamanho = 16, ...resto }) {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width={tamanho} height={tamanho} fill="currentColor" viewBox="0 0 16 16" aria-hidden="true" {...resto}>
      <path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001q.044.06.098.115l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1 1 0 0 0-.115-.1zM12 6.5a5.5 5.5 0 1 1-11 0 5.5 5.5 0 0 1 11 0" />
    </svg>
  )
}

export function IconeLocalizacao({ tamanho = 16, ...resto }) {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width={tamanho} height={tamanho} fill="currentColor" viewBox="0 0 16 16" aria-hidden="true" {...resto}>
      <path d="M12.166 8.94c-.524 1.062-1.234 2.12-1.96 3.07A32 32 0 0 1 8 14.58a32 32 0 0 1-2.206-2.57c-.726-.95-1.436-2.008-1.96-3.07C3.304 7.867 3 6.862 3 6a5 5 0 0 1 10 0c0 .862-.305 1.867-.834 2.94M8 16s6-5.686 6-10A6 6 0 0 0 2 6c0 4.314 6 10 6 10" />
      <path d="M8 8a2 2 0 1 1 0-4 2 2 0 0 1 0 4m0 1a3 3 0 1 0 0-6 3 3 0 0 0 0 6" />
    </svg>
  )
}

export function IconeEstrela({ tamanho = 16, ...resto }) {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width={tamanho} height={tamanho} fill="currentColor" viewBox="0 0 16 16" aria-hidden="true" {...resto}>
      <path d="M3.612 15.443c-.386.198-.824-.149-.746-.592l.83-4.73L.173 6.765c-.329-.314-.158-.888.283-.95l4.898-.696L7.538.792c.197-.39.73-.39.927 0l2.184 4.327 4.898.696c.441.062.612.636.282.95l-3.522 3.356.83 4.73c.078.443-.36.79-.746.592L8 13.187l-4.389 2.256z" />
    </svg>
  )
}

export function IconeSetaEsquerda({ tamanho = 16, ...resto }) {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width={tamanho} height={tamanho} fill="currentColor" viewBox="0 0 16 16" aria-hidden="true" {...resto}>
      <path fillRule="evenodd" d="M11.354 1.646a.5.5 0 0 1 0 .708L5.707 8l5.647 5.646a.5.5 0 0 1-.708.708l-6-6a.5.5 0 0 1 0-.708l6-6a.5.5 0 0 1 .708 0" />
    </svg>
  )
}

export function IconeSetaDireita({ tamanho = 16, ...resto }) {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width={tamanho} height={tamanho} fill="currentColor" viewBox="0 0 16 16" aria-hidden="true" {...resto}>
      <path fillRule="evenodd" d="M4.646 1.646a.5.5 0 0 1 .708 0l6 6a.5.5 0 0 1 0 .708l-6 6a.5.5 0 0 1-.708-.708L10.293 8 4.646 2.354a.5.5 0 0 1 0-.708" />
    </svg>
  )
}

export function IconeCalendario({ tamanho = 16, ...resto }) {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width={tamanho} height={tamanho} fill="currentColor" viewBox="0 0 16 16" aria-hidden="true" {...resto}>
      <path d="M6.445 11.688V6.354h-.633A13 13 0 0 0 4.5 7.16v.695c.375-.257.969-.62 1.258-.777h.012v4.61zm1.188-1.305c.047.64.594 1.406 1.703 1.406 1.258 0 2-1.066 2-2.871 0-1.934-.781-2.668-1.953-2.668-.926 0-1.797.672-1.797 1.809 0 1.16.824 1.77 1.676 1.77.746 0 1.23-.376 1.383-.79h.027c-.004 1.316-.461 2.164-1.305 2.164-.664 0-1.008-.45-1.05-.82zm2.953-2.317c0 .696-.559 1.18-1.184 1.18-.601 0-1.144-.383-1.144-1.2 0-.823.582-1.21 1.168-1.21.633 0 1.16.398 1.16 1.23" />
      <path d="M3.5 0a.5.5 0 0 1 .5.5V1h8V.5a.5.5 0 0 1 1 0V1h1a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V3a2 2 0 0 1 2-2h1V.5a.5.5 0 0 1 .5-.5M1 4v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4z" />
    </svg>
  )
}
