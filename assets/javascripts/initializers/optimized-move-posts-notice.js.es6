import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: 'optimized-move-posts-notice',
  initialize() {
     withPluginApi("0.8.31", api => {       
       api.addPostSmallActionIcon("optimized_move_posts","sign-in-alt")
     });

  }
}