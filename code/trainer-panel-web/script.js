document.addEventListener('DOMContentLoaded', () => {

    // --- VARIÁVEIS E CONSTANTES ---
    const BASE_URL = '/api';
    let USER_ID = null; // Deveria ser obtido após o login

    // --- ELEMENTOS DO DOM ---
    const trainerNameEl = document.getElementById('trainer-name');
    const trainerCodeEl = document.getElementById('trainer-code');
    const athleteCountEl = document.getElementById('athlete-count');
    const shareButton = document.getElementById('share-button');
    const viewAthletesButton = document.getElementById('view-athletes-button');
    const createWorkoutButton = document.getElementById('create-workout-button');
    const viewWorkoutsButton = document.getElementById('view-workouts-button');
    const menuButton = document.getElementById('menu-button');
    const drawer = document.getElementById('drawer');
    const scrim = document.getElementById('scrim');

    // --- FUNÇÕES DE API (Simuladas) ---
    
    /**
     * Busca os dados essenciais do treinador no backend.
     * Em um app real, isso ocorreria após o login.
     * O token de autenticação seria enviado no header.
     */
    async function fetchTrainerData(userId) {
        // Exemplo de como seria a chamada real com fetch:
        /*
        try {
            const response = await fetch(`${BASE_URL}/usuario/${userId}`, {
                headers: {
                    'Authorization': 'Bearer SEU_TOKEN_JWT'
                }
            });
            if (!response.ok) {
                throw new Error('Erro ao buscar dados do treinador');
            }
            const data = await response.json();
            return {
                userName: data.nome,
                shareCode: data.codigo_compartilhamento
            };
        } catch (error) {
            console.error(error);
            return { userName: 'Falha', shareCode: 'Erro' };
        }
        */

        // Por enquanto, usamos dados mockados para demonstração:
        console.log("Buscando dados do treinador...");
        return new Promise(resolve => {
            setTimeout(() => {
                resolve({
                    userName: 'Carlos',
                    shareCode: 'TRN-XF87D'
                });
            }, 500);
        });
    }

    /**
     * Busca a contagem de atletas vinculados a este treinador.
     * No seu código Flutter, isso era um TODO. Aqui está como poderia ser implementado.
     */
    async function fetchAthleteCount(trainerId) {
        // Exemplo de chamada real:
        /*
        try {
            const response = await fetch(`${BASE_URL}/treinador/${trainerId}/atletas/contagem`, {
                headers: { 'Authorization': 'Bearer SEU_TOKEN_JWT' }
            });
             if (!response.ok) throw new Error('Erro ao contar atletas');
            const data = await response.json();
            return data.totalAtletas;
        } catch (error) {
            console.error(error);
            return 0;
        }
        */

        // Dados mockados:
        console.log("Buscando contagem de atletas...");
        return new Promise(resolve => {
            setTimeout(() => {
                resolve(15); // Exemplo de valor
            }, 800);
        });
    }

    // --- FUNÇÕES DE UI E EVENTOS ---

    /**
     * Atualiza a UI com os dados recebidos do backend.
     */
    function updateUI(trainerData, athleteCount) {
        trainerNameEl.textContent = trainerData.userName.split(' ')[0];
        trainerCodeEl.textContent = trainerData.shareCode;
        athleteCountEl.textContent = athleteCount;
    }

    /**
     * Manipula o compartilhamento do código do treinador.
     * Equivalente a `_shareTrainerCode` no Flutter.
     */
    async function handleShare() {
        const shareCode = trainerCodeEl.textContent;
        const shareText = `Olá! Use meu código ${shareCode} para se conectar comigo como seu treinador no Connect Sports.`;

        if (navigator.share) {
            try {
                await navigator.share({
                    title: 'Código de Treinador Connect Sports',
                    text: shareText,
                });
                console.log('Código compartilhado com sucesso!');
            } catch (error) {
                console.error('Erro ao compartilhar:', error);
            }
        } else {
            // Fallback para navegadores que não suportam a Web Share API
            navigator.clipboard.writeText(shareText).then(() => {
                 alert('Texto de convite copiado para a área de transferência!');
            });
        }
    }

    /**
     * Abre e fecha o drawer de navegação.
     */
    function toggleDrawer() {
        drawer.classList.toggle('open');
        scrim.classList.toggle('visible');
    }

    // --- INICIALIZAÇÃO E EVENT LISTENERS ---

    async function initializePanel() {
        // Em um app real, USER_ID viria do estado de autenticação.
        USER_ID = 1; // ID de exemplo para o treinador

        const trainerData = await fetchTrainerData(USER_ID);
        const athleteCount = await fetchAthleteCount(USER_ID);
        
        updateUI(trainerData, athleteCount);
    }

    // Adiciona os listeners de eventos aos botões
    shareButton.addEventListener('click', handleShare);

    // Para os botões de navegação, podemos simplesmente alertar ou redirecionar
    viewAthletesButton.addEventListener('click', () => {
        // window.location.href = '/atletas.html'; // Exemplo de redirecionamento
        alert('Navegando para a tela "Meus Atletas"...');
    });

    createWorkoutButton.addEventListener('click', () => {
        // window.location.href = '/criar-treino.html';
        alert('Navegando para a tela "Criar Treino"...');
    });

    viewWorkoutsButton.addEventListener('click', () => {
        // window.location.href = '/treinos.html';
        alert('Navegando para a tela "Ver Treinos"...');
    });

    // Eventos do Drawer
    menuButton.addEventListener('click', toggleDrawer);
    scrim.addEventListener('click', toggleDrawer);


    // Inicia o painel
    initializePanel();
});